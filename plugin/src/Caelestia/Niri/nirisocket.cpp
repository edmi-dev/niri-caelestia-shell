#include "nirisocket.hpp"

#include <qjsondocument.h>
#include <qloggingcategory.h>
#include <qprocess.h>

#include <memory>

namespace caelestia::niri {

Q_LOGGING_CATEGORY(lcNiriSocket, "caelestia.niri.socket", QtInfoMsg)

namespace {

QString niriSocketPath() {
    return QProcessEnvironment::systemEnvironment().value(QStringLiteral("NIRI_SOCKET"));
}

} // namespace

// NiriEventSocket

NiriEventSocket::NiriEventSocket(QObject* parent)
    : QObject(parent)
    , m_socket(new QLocalSocket(this)) {
    m_reconnectTimer.setSingleShot(true);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &NiriEventSocket::connectToNiri);

    connect(m_socket, &QLocalSocket::connected, this, &NiriEventSocket::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &NiriEventSocket::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &NiriEventSocket::onReadyRead);
    connect(m_socket, &QLocalSocket::errorOccurred, this, &NiriEventSocket::onError);
}

void NiriEventSocket::connectToNiri() {
    const auto path = niriSocketPath();
    if (path.isEmpty()) {
        qCWarning(lcNiriSocket) << "NIRI_SOCKET not set, niri IPC unavailable";
        return;
    }

    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }

    m_readBuffer.clear();
    m_handshakeDone = false;
    m_socket->connectToServer(path);
}

void NiriEventSocket::disconnectFromNiri() {
    m_reconnectTimer.stop();
    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }
}

bool NiriEventSocket::isConnected() const {
    return m_socket->state() == QLocalSocket::ConnectedState && m_handshakeDone;
}

void NiriEventSocket::onConnected() {
    qCDebug(lcNiriSocket) << "Connected, requesting event stream";
    m_socket->write("\"EventStream\"\n");
    m_socket->flush();
}

void NiriEventSocket::onDisconnected() {
    qCDebug(lcNiriSocket) << "Event stream disconnected";
    m_handshakeDone = false;
    emit disconnected();
    scheduleReconnect();
}

void NiriEventSocket::onReadyRead() {
    m_readBuffer.append(m_socket->readAll());

    qsizetype pos;
    while ((pos = m_readBuffer.indexOf('\n')) != -1) {
        const auto line = m_readBuffer.left(pos).trimmed();
        m_readBuffer.remove(0, pos + 1);
        if (!line.isEmpty()) {
            processLine(line);
        }
    }
}

void NiriEventSocket::processLine(const QByteArray& line) {
    QJsonParseError err;
    const auto doc = QJsonDocument::fromJson(line, &err);
    if (err.error != QJsonParseError::NoError) {
        qCWarning(lcNiriSocket) << "JSON parse error:" << err.errorString();
        return;
    }

    const auto obj = doc.object();

    if (!m_handshakeDone) {
        // First reply to "EventStream" is {"Ok":"Handled"}
        if (!obj.contains(QStringLiteral("Ok"))) {
            qCWarning(lcNiriSocket) << "Event stream handshake failed, got:" << doc.toJson(QJsonDocument::Compact);
            disconnectFromNiri();
            return;
        }

        m_handshakeDone = true;
        m_reconnectDelay = 1000;
        qCDebug(lcNiriSocket) << "Event stream active";
        emit connected();
        return;
    }

    if (obj.isEmpty()) {
        qCWarning(lcNiriSocket) << "Received empty event";
        return;
    }

    emit eventReceived(obj);
}

void NiriEventSocket::onError(QLocalSocket::LocalSocketError error) {
    if (error == QLocalSocket::PeerClosedError) {
        return; // Handled by onDisconnected
    }
    qCWarning(lcNiriSocket) << "Event socket error:" << m_socket->errorString();
    scheduleReconnect();
}

void NiriEventSocket::scheduleReconnect() {
    if (!m_reconnectTimer.isActive()) {
        qCDebug(lcNiriSocket) << "Reconnecting in" << m_reconnectDelay << "ms";
        m_reconnectTimer.start(m_reconnectDelay);
        m_reconnectDelay = qMin(m_reconnectDelay * 2, 30000);
    }
}

// NiriRequestSocket

NiriRequestSocket::NiriRequestSocket(QObject* parent)
    : QObject(parent) {}

void NiriRequestSocket::request(const QByteArray& payload, Callback callback) {
    m_queue.push_back({ payload, std::move(callback) });
    if (!m_busy) {
        processQueue();
    }
}

void NiriRequestSocket::action(const QByteArray& payload) {
    m_queue.push_back({ payload, nullptr });
    if (!m_busy) {
        processQueue();
    }
}

void NiriRequestSocket::processQueue() {
    if (m_queue.empty()) {
        m_busy = false;
        return;
    }

    m_busy = true;
    const auto req = std::move(m_queue.front());
    m_queue.pop_front();
    startRequest(req);
}

void NiriRequestSocket::startRequest(const PendingRequest& req) {
    const auto path = niriSocketPath();
    if (path.isEmpty()) {
        qCWarning(lcNiriSocket) << "NIRI_SOCKET not set, dropping request";
        if (req.callback) {
            req.callback(false, {});
        }
        processQueue();
        return;
    }

    auto* sock = new QLocalSocket(this);
    const auto payload = req.payload;
    const auto callback = req.callback;
    const auto buffer = std::make_shared<QByteArray>();
    // errorOccurred (e.g. PeerClosedError) and disconnected can both fire for one request; finish exactly once
    // (the fork-legacy version called the callback and advanced the queue twice).
    const auto finished = std::make_shared<bool>(false);

    const auto finish = [this, sock, buffer, callback, finished](bool socketOk) {
        if (*finished) {
            return;
        }
        *finished = true;

        if (callback) {
            const auto line = buffer->trimmed();
            QJsonParseError err;
            const auto doc = QJsonDocument::fromJson(line, &err);
            if (line.isEmpty() || err.error != QJsonParseError::NoError) {
                if (socketOk || !line.isEmpty()) {
                    qCWarning(lcNiriSocket) << "Invalid reply:" << err.errorString();
                }
                callback(false, {});
            } else {
                const auto obj = doc.object();
                if (obj.contains(QStringLiteral("Ok"))) {
                    callback(true, QJsonObject{ { QStringLiteral("result"), obj.value(QStringLiteral("Ok")) } });
                } else {
                    qCWarning(lcNiriSocket) << "IPC error:" << doc.toJson(QJsonDocument::Compact);
                    callback(false, obj);
                }
            }
        }

        sock->deleteLater();
        processQueue();
    };

    connect(sock, &QLocalSocket::connected, this, [sock, payload]() {
        sock->write(payload + '\n');
        sock->flush();
    });

    connect(sock, &QLocalSocket::readyRead, this, [sock, buffer]() {
        buffer->append(sock->readAll());
        if (buffer->contains('\n')) {
            sock->disconnectFromServer();
        }
    });

    connect(sock, &QLocalSocket::disconnected, this, [finish]() {
        finish(true);
    });

    connect(sock, &QLocalSocket::errorOccurred, this, [sock, finish](QLocalSocket::LocalSocketError error) {
        if (error != QLocalSocket::PeerClosedError) {
            qCWarning(lcNiriSocket) << "Request socket error:" << sock->errorString();
        }
        finish(error == QLocalSocket::PeerClosedError);
    });

    sock->connectToServer(path);
}

} // namespace caelestia::niri
