#include "niriipc.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonvalue.h>
#include <qloggingcategory.h>

#include <algorithm>

namespace caelestia::niri {

Q_LOGGING_CATEGORY(lcNiriIpc, "caelestia.niri.ipc", QtInfoMsg)

namespace {

const QString kId = QStringLiteral("id");
const QString kIdx = QStringLiteral("idx");
const QString kOutput = QStringLiteral("output");
const QString kIsActive = QStringLiteral("is_active");
const QString kIsFocused = QStringLiteral("is_focused");
const QString kWorkspaceId = QStringLiteral("workspace_id");
const QString kLayout = QStringLiteral("layout");
const QString kPosInScrolling = QStringLiteral("pos_in_scrolling_layout");

int toIndex(qsizetype i) {
    return static_cast<int>(i);
}

} // namespace

// NiriListModel

NiriListModel::NiriListModel(QObject* parent)
    : QAbstractListModel(parent) {}

QHash<int, QByteArray> NiriListModel::roleNames() const {
    return { { ObjectRole, "modelData" } };
}

int NiriListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return toIndex(m_items.size());
}

QVariant NiriListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size() || role != ObjectRole) {
        return {};
    }
    return m_items.at(index.row());
}

void NiriListModel::resetData(const QVariantList& items) {
    beginResetModel();
    m_items = items;
    endResetModel();
}

void NiriListModel::appendItem(const QVariantMap& item) {
    const auto row = toIndex(m_items.size());
    beginInsertRows({}, row, row);
    m_items.append(item);
    endInsertRows();
}

void NiriListModel::setItem(int idx, const QVariantMap& item) {
    if (idx < 0 || idx >= m_items.size()) {
        return;
    }
    m_items[idx] = item;
    emit dataChanged(index(idx), index(idx), { ObjectRole });
}

void NiriListModel::removeItem(int idx) {
    if (idx < 0 || idx >= m_items.size()) {
        return;
    }
    beginRemoveRows({}, idx, idx);
    m_items.removeAt(idx);
    endRemoveRows();
}

const QVariantList& NiriListModel::items() const {
    return m_items;
}

// NiriIpc

NiriIpc::NiriIpc(QObject* parent)
    : NiriIpc(true, parent) {}

NiriIpc::NiriIpc(bool autoConnect, QObject* parent)
    : QObject(parent)
    , m_eventSocket(this)
    , m_requestSocket(this)
    , m_workspacesModel(new NiriListModel(this))
    , m_windowsModel(new NiriListModel(this)) {
    connect(&m_eventSocket, &NiriEventSocket::connected, this, &NiriIpc::onEventStreamConnected);
    connect(&m_eventSocket, &NiriEventSocket::disconnected, this, &NiriIpc::onEventStreamDisconnected);
    connect(&m_eventSocket, &NiriEventSocket::eventReceived, this, &NiriIpc::processEvent);

    if (autoConnect) {
        setupLedWatchers();
        m_eventSocket.connectToNiri();
    }
}

bool NiriIpc::available() const {
    return m_available;
}

QAbstractListModel* NiriIpc::workspacesModel() const {
    return m_workspacesModel;
}

QVariantList NiriIpc::workspaces() const {
    return m_workspacesModel->items();
}

int NiriIpc::focusedWorkspaceIndex() const {
    return m_focusedWorkspaceIndex;
}

int NiriIpc::focusedWorkspaceId() const {
    return m_focusedWorkspaceId;
}

QString NiriIpc::focusedMonitorName() const {
    return m_focusedMonitorName;
}

QVariantList NiriIpc::currentOutputWorkspaces() const {
    return m_currentOutputWorkspaces;
}

QVariantMap NiriIpc::workspaceHasWindows() const {
    return m_workspaceHasWindows;
}

QAbstractListModel* NiriIpc::windowsModel() const {
    return m_windowsModel;
}

QVariantList NiriIpc::windows() const {
    return m_windowsModel->items();
}

int NiriIpc::focusedWindowIndex() const {
    return m_focusedWindowIndex;
}

QString NiriIpc::focusedWindowId() const {
    return m_focusedWindowId;
}

QString NiriIpc::focusedWindowTitle() const {
    return m_focusedWindowTitle;
}

QString NiriIpc::focusedWindowClass() const {
    return m_focusedWindowClass;
}

QVariantMap NiriIpc::focusedWindow() const {
    return m_focusedWindow;
}

QVariantMap NiriIpc::lastFocusedWindow() const {
    return m_lastFocusedWindow;
}

QString NiriIpc::scrollDirection() const {
    return m_scrollDirection;
}

bool NiriIpc::inOverview() const {
    return m_inOverview;
}

QVariantMap NiriIpc::outputs() const {
    return m_outputs;
}

QVariantList NiriIpc::kbLayoutsArray() const {
    return m_kbLayoutsArray;
}

int NiriIpc::kbLayoutIndex() const {
    return m_kbLayoutIndex;
}

QString NiriIpc::kbLayouts() const {
    return m_kbLayouts;
}

QString NiriIpc::defaultKbLayout() const {
    if (!m_kbLayoutsArray.isEmpty()) {
        return m_kbLayoutsArray.first().toString();
    }
    return QStringLiteral("?");
}

QString NiriIpc::kbLayout() const {
    if (m_kbLayoutIndex >= 0 && m_kbLayoutIndex < m_kbLayoutsArray.size()) {
        const auto name = m_kbLayoutsArray.at(m_kbLayoutIndex).toString();
        if (name.size() >= 2) {
            return name.left(2).toLower();
        }
    }
    return QStringLiteral("?");
}

bool NiriIpc::capsLock() const {
    return m_capsLock;
}

bool NiriIpc::numLock() const {
    return m_numLock;
}

// Actions

bool NiriIpc::action(const QString& actionName, const QVariantList& args) {
    if (!m_available) {
        return false;
    }
    m_requestSocket.action(actionPayload(actionName, args));
    return true;
}

QByteArray NiriIpc::actionPayload(const QString& actionName, const QVariantList& args) {
    // kebab-case CLI name -> PascalCase IPC name
    QString name;
    bool capitalizeNext = true;
    for (const auto& c : actionName) {
        if (c == u'-') {
            capitalizeNext = true;
        } else {
            name += capitalizeNext ? c.toUpper() : c;
            capitalizeNext = false;
        }
    }

    const auto isFocusWs = name == QStringLiteral("FocusWorkspace");
    const auto isMoveToWs = name == QStringLiteral("MoveWindowToWorkspace");
    const auto firstArg = args.isEmpty() ? QString() : args.at(0).toString();

    QJsonValue inner;

    if (args.size() == 2 && firstArg == QStringLiteral("--id") && (isFocusWs || isMoveToWs)) {
        // Workspace reference by id. {"Index": N} is resolved on the *focused* output, so with
        // several outputs it may point at a different workspace.
        QJsonObject obj{ { QStringLiteral("reference"), QJsonObject{ { QStringLiteral("Id"), args.at(1).toLongLong() } } } };
        if (isMoveToWs) {
            obj[QStringLiteral("window_id")] = QJsonValue::Null;
            obj[QStringLiteral("focus")] = true;
        }
        inner = obj;
    } else if (args.size() >= 2 && firstArg == QStringLiteral("--id")) {
        // FocusWindow, CloseWindow, ToggleWindowFloating, ...: {"id": N}
        inner = QJsonObject{ { kId, args.at(1).toLongLong() } };
    } else if (args.size() == 2 && firstArg == QStringLiteral("-d")) {
        // DoScreenTransition: {"delay_ms": N}
        inner = QJsonObject{ { QStringLiteral("delay_ms"), args.at(1).toInt() } };
    } else if (args.isEmpty()) {
        if (name == QStringLiteral("ScreenshotWindow")) {
            inner = QJsonObject{ { kId, QJsonValue::Null }, { QStringLiteral("write_to_disk"), true },
                { QStringLiteral("path"), QJsonValue::Null } };
        } else if (name == QStringLiteral("CloseWindow") || name == QStringLiteral("ToggleWindowFloating")) {
            inner = QJsonObject{ { kId, QJsonValue::Null } };
        } else {
            inner = QJsonObject();
        }
    } else if (args.size() == 1) {
        bool isNumber = false;
        const auto num = args.at(0).toLongLong(&isNumber);
        const QJsonObject indexRef{ { QStringLiteral("Index"), num } };

        if (isFocusWs) {
            inner = QJsonObject{ { QStringLiteral("reference"), indexRef } };
        } else if (isMoveToWs) {
            inner = QJsonObject{ { QStringLiteral("window_id"), QJsonValue::Null },
                { QStringLiteral("reference"), indexRef }, { QStringLiteral("focus"), true } };
        } else if (name == QStringLiteral("MoveColumnToIndex")) {
            inner = QJsonObject{ { QStringLiteral("index"), num } };
        } else if (isNumber) {
            inner = QJsonObject{ { kId, num } };
        } else {
            inner = args.at(0).toString();
        }
    } else {
        qCWarning(lcNiriIpc) << "Unhandled action args for" << actionName << args;
        inner = QJsonObject();
    }

    const QJsonObject wrapper{ { QStringLiteral("Action"), QJsonObject{ { name, inner } } } };
    return QJsonDocument(wrapper).toJson(QJsonDocument::Compact);
}

int NiriIpc::getWorkspaceIdxById(int workspaceId) const {
    for (const auto& v : m_workspacesModel->items()) {
        const auto ws = v.toMap();
        if (ws.value(kId).toInt() == workspaceId) {
            return ws.value(kIdx).toInt();
        }
    }
    return -1;
}

QVariantList NiriIpc::getWindowsByWorkspaceId(int wsId) const {
    QVariantList res;
    for (const auto& w : m_windowsModel->items()) {
        if (w.toMap().value(kWorkspaceId).toInt() == wsId) {
            res.append(w);
        }
    }
    return res;
}

QVariantList NiriIpc::getWindowsByWorkspaceIndex(int index) const {
    const auto& wsList = m_workspacesModel->items();
    if (index < 0 || index >= wsList.size()) {
        return {};
    }
    return getWindowsByWorkspaceId(wsList.at(index).toMap().value(kId).toInt());
}

QVariantList NiriIpc::getActiveWorkspaceWindows() const {
    if (m_focusedWorkspaceId < 0) {
        return {};
    }
    return getWindowsByWorkspaceId(m_focusedWorkspaceId);
}

// Event stream

void NiriIpc::onEventStreamConnected() {
    m_available = true;
    emit availableChanged();
    fetchInitialState();
}

void NiriIpc::onEventStreamDisconnected() {
    m_available = false;
    emit availableChanged();
}

void NiriIpc::processEvent(const QJsonObject& event) {
    if (event.isEmpty()) {
        return;
    }

    const auto type = event.constBegin().key();
    const auto data = event.constBegin().value().toObject();

    if (type == QStringLiteral("WorkspacesChanged")) {
        handleWorkspacesChanged(data);
    } else if (type == QStringLiteral("WorkspaceActivated")) {
        handleWorkspaceActivated(data);
    } else if (type == QStringLiteral("WindowsChanged")) {
        handleWindowsChanged(data);
    } else if (type == QStringLiteral("WindowOpenedOrChanged")) {
        handleWindowOpenedOrChanged(data);
    } else if (type == QStringLiteral("WindowClosed")) {
        handleWindowClosed(data);
    } else if (type == QStringLiteral("WindowFocusChanged")) {
        handleWindowFocusChanged(data);
    } else if (type == QStringLiteral("WindowLayoutsChanged")) {
        handleWindowLayoutsChanged(data);
    } else if (type == QStringLiteral("KeyboardLayoutsChanged")) {
        handleKeyboardLayoutsChanged(data);
    } else if (type == QStringLiteral("OverviewOpenedOrClosed")) {
        handleOverviewOpenedOrClosed(data);
    } else if (type == QStringLiteral("OutputsChanged")) {
        // UNVERIFIED: carried over from fork-legacy, not confirmed to exist in niri (see DECISIONS.md)
        handleOutputsChanged(data);
    }
}

void NiriIpc::applyResponse(const QJsonObject& result) {
    // Request replies are wrapped in PascalCase keys ({"Workspaces": [...]}), event payloads use
    // snake_case keys ({"workspaces": [...]}); rewrap so both go through the same handlers.
    if (result.contains(QStringLiteral("Workspaces"))) {
        handleWorkspacesChanged({ { QStringLiteral("workspaces"), result.value(QStringLiteral("Workspaces")) } });
    } else if (result.contains(QStringLiteral("Windows"))) {
        handleWindowsChanged({ { QStringLiteral("windows"), result.value(QStringLiteral("Windows")) } });
    } else if (result.contains(QStringLiteral("FocusedWindow"))) {
        const auto win = result.value(QStringLiteral("FocusedWindow"));
        handleWindowFocusChanged({ { kId, win.isObject() ? win.toObject().value(kId) : QJsonValue::Null } });
    } else if (result.contains(QStringLiteral("Outputs"))) {
        m_outputs = result.value(QStringLiteral("Outputs")).toObject().toVariantMap();
        emit outputsChanged();
    } else if (result.contains(QStringLiteral("KeyboardLayouts"))) {
        handleKeyboardLayoutsChanged(
            { { QStringLiteral("keyboard_layouts"), result.value(QStringLiteral("KeyboardLayouts")) } });
    }
}

void NiriIpc::fetchInitialState() {
    const auto apply = [this](bool ok, const QJsonObject& resp) {
        if (ok) {
            applyResponse(resp.value(QStringLiteral("result")).toObject());
        }
    };

    m_requestSocket.request("\"Workspaces\"", apply);
    m_requestSocket.request("\"Windows\"", apply);
    m_requestSocket.request("\"FocusedWindow\"", apply);
    m_requestSocket.request("\"Outputs\"", apply);
    m_requestSocket.request("\"KeyboardLayouts\"", apply);
}

// Event handlers

void NiriIpc::handleWorkspacesChanged(const QJsonObject& data) {
    auto wsList = data.value(QStringLiteral("workspaces")).toArray().toVariantList();

    std::sort(wsList.begin(), wsList.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value(kIdx).toInt() < b.toMap().value(kIdx).toInt();
    });

    m_workspacesModel->resetData(wsList);

    m_focusedWorkspaceIndex = -1;
    m_focusedWorkspaceId = -1;
    for (qsizetype i = 0; i < wsList.size(); ++i) {
        const auto ws = wsList.at(i).toMap();
        if (ws.value(kIsFocused).toBool()) {
            m_focusedWorkspaceIndex = toIndex(i);
            m_focusedWorkspaceId = ws.value(kId).toInt();
            m_focusedMonitorName = ws.value(kOutput).toString();
            break;
        }
    }

    if (m_focusedWorkspaceIndex < 0 && !wsList.isEmpty()) {
        m_focusedWorkspaceIndex = 0;
    }

    updateCurrentOutputWorkspaces();
    updateWorkspaceHasWindows();
    emit workspacesChanged();
    emit focusedWorkspaceChanged();
}

void NiriIpc::handleWorkspaceActivated(const QJsonObject& data) {
    const auto id = data.value(kId).toInt();
    // focused == false: the workspace became active on an unfocused output (hotplug, open-on-output,
    // window moved to another output). niri's focus does not change, only is_active on that output.
    const auto focused = data.value(QStringLiteral("focused")).toBool();

    const auto& wsList = m_workspacesModel->items();
    qsizetype target = -1;
    for (qsizetype i = 0; i < wsList.size(); ++i) {
        if (wsList.at(i).toMap().value(kId).toInt() == id) {
            target = i;
            break;
        }
    }

    if (target >= 0) {
        const auto output = wsList.at(target).toMap().value(kOutput).toString();
        if (focused) {
            m_focusedWorkspaceId = id;
            m_focusedWorkspaceIndex = toIndex(target);
            m_focusedMonitorName = output;
        }

        const auto count = wsList.size();
        for (qsizetype j = 0; j < count; ++j) {
            auto w = m_workspacesModel->items().at(j).toMap();
            bool changed = false;
            if (w.value(kOutput).toString() == output) {
                w[kIsActive] = j == target;
                changed = true;
            }
            if (focused) {
                // is_focused is global, not per output
                w[kIsFocused] = j == target;
                changed = true;
            }
            if (changed) {
                m_workspacesModel->setItem(toIndex(j), w);
            }
        }
    }

    updateCurrentOutputWorkspaces();
    emit workspacesChanged();
    emit focusedWorkspaceChanged();
}

void NiriIpc::handleWindowsChanged(const QJsonObject& data) {
    auto winList = data.value(QStringLiteral("windows")).toArray().toVariantList();

    // Ensure every window has a layout object
    for (auto& v : winList) {
        auto w = v.toMap();
        if (!w.contains(kLayout)) {
            w[kLayout] = QVariantMap();
            v = w;
        }
    }

    m_windowsModel->resetData(winList);

    sortWindowsList();
    rebuildWindowIndex();
    if (!m_focusedWindowId.isEmpty()) {
        m_focusedWindowIndex = findWindowIndexById(m_focusedWindowId.toLongLong());
    }
    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
}

void NiriIpc::handleWindowOpenedOrChanged(const QJsonObject& data) {
    const auto winObj = data.value(QStringLiteral("window")).toObject();
    if (winObj.isEmpty()) {
        return;
    }

    const auto window = winObj.toVariantMap();
    const auto winId = window.value(kId).toLongLong();
    const auto existingIdx = findWindowIndexById(winId);

    if (existingIdx >= 0) {
        auto existing = m_windowsModel->items().at(existingIdx).toMap();
        for (auto it = window.begin(); it != window.end(); ++it) {
            existing[it.key()] = it.value();
        }
        m_windowsModel->setItem(existingIdx, existing);
    } else {
        m_windowsModel->appendItem(window);
    }

    sortWindowsList();
    rebuildWindowIndex();

    if (window.value(kIsFocused).toBool()) {
        m_focusedWindowId = QString::number(winId);
    }
    if (!m_focusedWindowId.isEmpty()) {
        m_focusedWindowIndex = findWindowIndexById(m_focusedWindowId.toLongLong());
    }

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
    emit windowOpenedOrChanged(window);
}

void NiriIpc::handleWindowClosed(const QJsonObject& data) {
    const auto closedId = data.value(kId).toInteger();

    const auto idx = findWindowIndexById(closedId);
    if (idx >= 0) {
        m_windowsModel->removeItem(idx);
        rebuildWindowIndex();
    }

    if (m_focusedWindowId == QString::number(closedId)) {
        m_focusedWindowId.clear();
    }
    m_focusedWindowIndex = m_focusedWindowId.isEmpty() ? -1 : findWindowIndexById(m_focusedWindowId.toLongLong());

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
}

void NiriIpc::handleWindowFocusChanged(const QJsonObject& data) {
    const auto id = data.value(kId);
    if (!id.isNull() && !id.isUndefined()) {
        m_focusedWindowId = QString::number(id.toInteger());
        m_focusedWindowIndex = findWindowIndexById(id.toInteger());
    } else {
        m_focusedWindowId.clear();
        m_focusedWindowIndex = -1;
    }

    updateFocusedWindowFields();
}

void NiriIpc::handleWindowLayoutsChanged(const QJsonObject& data) {
    const auto changes = data.value(QStringLiteral("changes")).toArray();
    if (changes.isEmpty()) {
        return;
    }

    for (const auto& change : changes) {
        const auto pair = change.toArray();
        if (pair.size() != 2) {
            continue;
        }

        const auto idx = findWindowIndexById(pair.at(0).toInteger());
        if (idx >= 0) {
            auto w = m_windowsModel->items().at(idx).toMap();
            w[kLayout] = pair.at(1).toObject().toVariantMap();
            m_windowsModel->setItem(idx, w);
        }
    }

    sortWindowsList();
    rebuildWindowIndex();

    if (!m_focusedWindowId.isEmpty()) {
        m_focusedWindowIndex = findWindowIndexById(m_focusedWindowId.toLongLong());
    }

    updateFocusedWindowFields();
    emit windowsChanged();
}

void NiriIpc::handleOutputsChanged(const QJsonObject& data) {
    const auto outputs = data.value(QStringLiteral("outputs"));
    m_outputs = outputs.isObject() ? outputs.toObject().toVariantMap() : data.toVariantMap();
    emit outputsChanged();
}

void NiriIpc::handleKeyboardLayoutsChanged(const QJsonObject& data) {
    const auto kb = data.value(QStringLiteral("keyboard_layouts")).toObject();

    m_kbLayoutsArray = kb.value(QStringLiteral("names")).toArray().toVariantList();

    QStringList names;
    names.reserve(m_kbLayoutsArray.size());
    for (const auto& v : std::as_const(m_kbLayoutsArray)) {
        names.append(v.toString());
    }
    m_kbLayouts = names.isEmpty() ? QStringLiteral("?") : names.join(u',');

    const auto idx = kb.value(QStringLiteral("current_idx")).toInt(0);
    m_kbLayoutIndex = idx >= 0 && idx < m_kbLayoutsArray.size() ? idx : 0;

    emit keyboardChanged();
}

void NiriIpc::handleOverviewOpenedOrClosed(const QJsonObject& data) {
    const auto isOpen = data.value(QStringLiteral("is_open")).toBool();
    if (m_inOverview != isOpen) {
        m_inOverview = isOpen;
        emit inOverviewChanged();
    }
}

// Helpers

void NiriIpc::updateCurrentOutputWorkspaces() {
    if (m_focusedMonitorName.isEmpty()) {
        m_currentOutputWorkspaces = m_workspacesModel->items();
        return;
    }

    m_currentOutputWorkspaces.clear();
    for (const auto& v : m_workspacesModel->items()) {
        if (v.toMap().value(kOutput).toString() == m_focusedMonitorName) {
            m_currentOutputWorkspaces.append(v);
        }
    }
}

void NiriIpc::updateWorkspaceHasWindows() {
    QVariantMap newState;
    for (const auto& v : m_workspacesModel->items()) {
        newState[QString::number(v.toMap().value(kIdx).toInt())] = false;
    }

    for (const auto& v : m_windowsModel->items()) {
        const auto idx = getWorkspaceIdxById(v.toMap().value(kWorkspaceId).toInt());
        if (idx >= 0) {
            newState[QString::number(idx)] = true;
        }
    }

    if (m_workspaceHasWindows != newState) {
        m_workspaceHasWindows = newState;
        emit workspaceHasWindowsChanged();
    }
}

void NiriIpc::updateFocusedWindowFields() {
    const auto& winList = m_windowsModel->items();
    if (m_focusedWindowIndex >= 0 && m_focusedWindowIndex < winList.size()) {
        const auto win = winList.at(m_focusedWindowIndex).toMap();
        auto title = win.value(QStringLiteral("title")).toString();
        // Strip non-printable prefix characters
        while (!title.isEmpty() && title.at(0).unicode() < 0x20) {
            title.remove(0, 1);
        }
        m_focusedWindowTitle = title.isEmpty() ? QStringLiteral("(Unnamed window)") : title;
        m_focusedWindowClass = win.value(QStringLiteral("app_id")).toString();
        m_focusedWindow = win;

        // Track horizontal scroll direction between focused columns
        const auto pos = win.value(kLayout).toMap().value(kPosInScrolling).toList();
        if (pos.size() >= 2) {
            const auto currentCol = pos.at(0).toInt();
            if (m_lastFocusedColumn >= 0) {
                const auto newDir = currentCol > m_lastFocusedColumn   ? QStringLiteral("right")
                                    : currentCol < m_lastFocusedColumn ? QStringLiteral("left")
                                                                       : QStringLiteral("none");
                if (m_scrollDirection != newDir) {
                    m_scrollDirection = newDir;
                    emit scrollDirectionChanged();
                }
            }
            m_lastFocusedColumn = currentCol;
        }

        m_lastFocusedWindow = win;
        emit lastFocusedWindowChanged();
    } else {
        m_focusedWindowTitle.clear();
        m_focusedWindowClass = QStringLiteral("Desktop");
        m_focusedWindow.clear();
    }
    emit focusedWindowChanged();
}

void NiriIpc::sortWindowsList() {
    auto winList = m_windowsModel->items();
    std::stable_sort(winList.begin(), winList.end(), [](const QVariant& a, const QVariant& b) {
        const auto aPos = a.toMap().value(kLayout).toMap().value(kPosInScrolling).toList();
        const auto bPos = b.toMap().value(kLayout).toMap().value(kPosInScrolling).toList();
        const auto ax = aPos.size() >= 1 ? aPos.at(0).toInt() : 0;
        const auto ay = aPos.size() >= 2 ? aPos.at(1).toInt() : 0;
        const auto bx = bPos.size() >= 1 ? bPos.at(0).toInt() : 0;
        const auto by = bPos.size() >= 2 ? bPos.at(1).toInt() : 0;
        if (ax != bx) {
            return ax < bx;
        }
        return ay < by;
    });
    m_windowsModel->resetData(winList);
}

void NiriIpc::rebuildWindowIndex() {
    m_windowIndex.clear();
    const auto& winList = m_windowsModel->items();
    m_windowIndex.reserve(winList.size());
    for (qsizetype i = 0; i < winList.size(); ++i) {
        m_windowIndex.insert(winList.at(i).toMap().value(kId).toLongLong(), toIndex(i));
    }
}

int NiriIpc::findWindowIndexById(qint64 id) const {
    return m_windowIndex.value(id, -1);
}

// Caps/Num lock LEDs (/sys/class/leds)

void NiriIpc::setupLedWatchers() {
    const QDir ledsDir(QStringLiteral("/sys/class/leds"));
    if (!ledsDir.exists()) {
        return;
    }

    const auto entries = ledsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const auto& entry : entries) {
        const auto brightnessPath = ledsDir.filePath(entry) + QStringLiteral("/brightness");
        if (!QFile::exists(brightnessPath)) {
            continue;
        }

        if (entry.contains(QStringLiteral("capslock"), Qt::CaseInsensitive)) {
            m_capsLockPath = brightnessPath;
        } else if (entry.contains(QStringLiteral("numlock"), Qt::CaseInsensitive)) {
            m_numLockPath = brightnessPath;
        }
    }

    readLedState();

    // sysfs attributes don't support inotify, so poll
    if (!m_capsLockPath.isEmpty() || !m_numLockPath.isEmpty()) {
        m_ledPollTimer.setInterval(1000);
        connect(&m_ledPollTimer, &QTimer::timeout, this, &NiriIpc::readLedState);
        m_ledPollTimer.start();
    }
}

void NiriIpc::readLedState() {
    const auto readBrightness = [](const QString& path) {
        if (path.isEmpty()) {
            return false;
        }
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            return false;
        }
        return file.readAll().trimmed().toInt() > 0;
    };

    const auto newCaps = readBrightness(m_capsLockPath);
    const auto newNum = readBrightness(m_numLockPath);

    if (m_capsLock != newCaps) {
        m_capsLock = newCaps;
        emit capsLockChanged();
    }
    if (m_numLock != newNum) {
        m_numLock = newNum;
        emit numLockChanged();
    }
}

} // namespace caelestia::niri
