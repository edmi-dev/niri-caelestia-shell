#pragma once

#include <qbytearray.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <qobject.h>
#include <qtimer.h>

#include <deque>
#include <functional>

namespace caelestia::niri {

// Persistent EventStream connection to niri's IPC socket ($NIRI_SOCKET).
// Sends "EventStream", waits for the {"Ok":"Handled"} handshake, then emits one event per line.
// Reconnects with exponential backoff (1s .. 30s).
class NiriEventSocket : public QObject {
    Q_OBJECT

public:
    explicit NiriEventSocket(QObject* parent = nullptr);

    void connectToNiri();
    void disconnectFromNiri();
    [[nodiscard]] bool isConnected() const;

signals:
    void connected();
    void disconnected();
    void eventReceived(const QJsonObject& event);

private:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onError(QLocalSocket::LocalSocketError error);
    void processLine(const QByteArray& line);
    void scheduleReconnect();

    QLocalSocket* m_socket;
    QTimer m_reconnectTimer;
    QByteArray m_readBuffer;
    int m_reconnectDelay = 1000;
    bool m_handshakeDone = false;
};

// Request/action connection to niri's IPC socket.
// Requests are queued and each one uses a fresh connection, so replies never interleave with the event stream.
class NiriRequestSocket : public QObject {
    Q_OBJECT

public:
    // ok == true: response is {"result": <value of "Ok">}; ok == false: response is the raw reply (or empty)
    using Callback = std::function<void(bool ok, const QJsonObject& response)>;

    explicit NiriRequestSocket(QObject* parent = nullptr);

    void request(const QByteArray& payload, Callback callback);
    void action(const QByteArray& payload);

private:
    struct PendingRequest {
        QByteArray payload;
        Callback callback; // Empty for fire-and-forget
    };

    void processQueue();
    void startRequest(const PendingRequest& req);

    std::deque<PendingRequest> m_queue;
    bool m_busy = false;
};

} // namespace caelestia::niri
