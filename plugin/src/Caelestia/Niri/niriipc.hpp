#pragma once

#include "nirisocket.hpp"

#include <qabstractitemmodel.h>
#include <qhash.h>
#include <qjsonobject.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qtimer.h>
#include <qvariant.h>

namespace caelestia::niri {

// Flat list model of niri JSON objects, exposed to QML as `modelData`.
class NiriListModel : public QAbstractListModel {
    Q_OBJECT
    QML_ANONYMOUS

public:
    enum Roles {
        ObjectRole = Qt::UserRole + 1
    };

    explicit NiriListModel(QObject* parent = nullptr);

    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;
    [[nodiscard]] int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    [[nodiscard]] QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;

    void resetData(const QVariantList& items);
    void appendItem(const QVariantMap& item);
    void setItem(int idx, const QVariantMap& item);
    void removeItem(int idx);
    [[nodiscard]] const QVariantList& items() const;

private:
    QVariantList m_items;
};

// Native client for niri's IPC: keeps workspaces/windows/outputs/keyboard state in sync with the event stream
// and sends actions. Only services/Compositor.qml may use this type (see scripts/port/check-boundary.sh).
class NiriIpc : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Core
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

    // Workspaces
    Q_PROPERTY(QAbstractListModel* workspacesModel READ workspacesModel CONSTANT)
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(int focusedWorkspaceIndex READ focusedWorkspaceIndex NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(int focusedWorkspaceId READ focusedWorkspaceId NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QString focusedMonitorName READ focusedMonitorName NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QVariantList currentOutputWorkspaces READ currentOutputWorkspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QVariantMap workspaceHasWindows READ workspaceHasWindows NOTIFY workspaceHasWindowsChanged)

    // Windows
    Q_PROPERTY(QAbstractListModel* windowsModel READ windowsModel CONSTANT)
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(int focusedWindowIndex READ focusedWindowIndex NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowId READ focusedWindowId NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowTitle READ focusedWindowTitle NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowClass READ focusedWindowClass NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap lastFocusedWindow READ lastFocusedWindow NOTIFY lastFocusedWindowChanged)
    Q_PROPERTY(QString scrollDirection READ scrollDirection NOTIFY scrollDirectionChanged)
    Q_PROPERTY(bool inOverview READ inOverview NOTIFY inOverviewChanged)

    // Outputs
    Q_PROPERTY(QVariantMap outputs READ outputs NOTIFY outputsChanged)

    // Keyboard
    Q_PROPERTY(QVariantList kbLayoutsArray READ kbLayoutsArray NOTIFY keyboardChanged)
    Q_PROPERTY(int kbLayoutIndex READ kbLayoutIndex NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayouts READ kbLayouts NOTIFY keyboardChanged)
    Q_PROPERTY(QString defaultKbLayout READ defaultKbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayout READ kbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(bool capsLock READ capsLock NOTIFY capsLockChanged)
    Q_PROPERTY(bool numLock READ numLock NOTIFY numLockChanged)

public:
    explicit NiriIpc(QObject* parent = nullptr);
    // autoConnect == false: no socket connection and no LED polling (used by unit tests to feed fixtures)
    NiriIpc(bool autoConnect, QObject* parent);

    [[nodiscard]] bool available() const;

    [[nodiscard]] QAbstractListModel* workspacesModel() const;
    [[nodiscard]] QVariantList workspaces() const;
    [[nodiscard]] int focusedWorkspaceIndex() const;
    [[nodiscard]] int focusedWorkspaceId() const;
    [[nodiscard]] QString focusedMonitorName() const;
    [[nodiscard]] QVariantList currentOutputWorkspaces() const;
    [[nodiscard]] QVariantMap workspaceHasWindows() const;

    [[nodiscard]] QAbstractListModel* windowsModel() const;
    [[nodiscard]] QVariantList windows() const;
    [[nodiscard]] int focusedWindowIndex() const;
    [[nodiscard]] QString focusedWindowId() const;
    [[nodiscard]] QString focusedWindowTitle() const;
    [[nodiscard]] QString focusedWindowClass() const;
    [[nodiscard]] QVariantMap focusedWindow() const;
    [[nodiscard]] QVariantMap lastFocusedWindow() const;
    [[nodiscard]] QString scrollDirection() const;
    [[nodiscard]] bool inOverview() const;

    [[nodiscard]] QVariantMap outputs() const;

    [[nodiscard]] QVariantList kbLayoutsArray() const;
    [[nodiscard]] int kbLayoutIndex() const;
    [[nodiscard]] QString kbLayouts() const;
    [[nodiscard]] QString defaultKbLayout() const;
    [[nodiscard]] QString kbLayout() const;
    [[nodiscard]] bool capsLock() const;
    [[nodiscard]] bool numLock() const;

    // Sends a niri action, e.g. action("focus-workspace", {3}) or action("close-window", {"--id", 12})
    Q_INVOKABLE bool action(const QString& actionName, const QVariantList& args = {});
    // Builds the JSON payload for action() without sending it
    [[nodiscard]] static QByteArray actionPayload(const QString& actionName, const QVariantList& args);

    Q_INVOKABLE int getWorkspaceIdxById(int workspaceId) const;
    Q_INVOKABLE QVariantList getWindowsByWorkspaceId(int wsId) const;
    Q_INVOKABLE QVariantList getWindowsByWorkspaceIndex(int index) const;
    Q_INVOKABLE QVariantList getActiveWorkspaceWindows() const;

    // Applies one event-stream event, e.g. {"WorkspacesChanged": {...}}
    void processEvent(const QJsonObject& event);
    // Applies the "Ok" value of a request reply, e.g. request "Workspaces" -> {"Workspaces": [...]}
    void applyResponse(const QJsonObject& result);

signals:
    void availableChanged();
    void workspacesChanged();
    void focusedWorkspaceChanged();
    void workspaceHasWindowsChanged();
    void windowsChanged();
    void focusedWindowChanged();
    void lastFocusedWindowChanged();
    void scrollDirectionChanged();
    void inOverviewChanged();
    void outputsChanged();
    void keyboardChanged();
    void capsLockChanged();
    void numLockChanged();
    void windowOpenedOrChanged(const QVariantMap& windowData);
    // Config (re)load result; also sent once on every (re)connect to the event stream
    void configLoaded(bool failed);

private:
    void onEventStreamConnected();
    void onEventStreamDisconnected();

    void fetchInitialState();
    void refreshOutputs();
    void handleWorkspacesChanged(const QJsonObject& data);
    void handleWorkspaceActivated(const QJsonObject& data);
    void handleWindowsChanged(const QJsonObject& data);
    void handleWindowOpenedOrChanged(const QJsonObject& data);
    void handleWindowClosed(const QJsonObject& data);
    void handleWindowFocusChanged(const QJsonObject& data);
    void handleWindowLayoutsChanged(const QJsonObject& data);
    void handleWorkspaceActiveWindowChanged(const QJsonObject& data);
    void handleKeyboardLayoutsChanged(const QJsonObject& data);
    void handleKeyboardLayoutSwitched(const QJsonObject& data);
    void handleOverviewOpenedOrClosed(const QJsonObject& data);

    void updateCurrentOutputWorkspaces();
    void updateWorkspaceHasWindows();
    void updateFocusedWindowFields();
    void sortWindowsList();
    void rebuildWindowIndex();
    [[nodiscard]] int findWindowIndexById(qint64 id) const;
    void setupLedWatchers();
    void readLedState();

    NiriEventSocket m_eventSocket;
    NiriRequestSocket m_requestSocket;

    bool m_available = false;

    // Workspace state
    NiriListModel* m_workspacesModel;
    int m_focusedWorkspaceIndex = -1;
    int m_focusedWorkspaceId = -1;
    QString m_focusedMonitorName;
    QVariantList m_currentOutputWorkspaces;
    QVariantMap m_workspaceHasWindows;

    // Window state
    NiriListModel* m_windowsModel;
    QHash<qint64, int> m_windowIndex; // Window id -> row in m_windowsModel
    int m_focusedWindowIndex = -1;
    QString m_focusedWindowId;
    QString m_focusedWindowTitle;
    QString m_focusedWindowClass;
    QVariantMap m_focusedWindow;
    QVariantMap m_lastFocusedWindow;
    int m_lastFocusedColumn = -1;
    QString m_scrollDirection = QStringLiteral("none");
    bool m_inOverview = false;

    // Output state
    QVariantMap m_outputs;

    // Keyboard state
    QVariantList m_kbLayoutsArray;
    int m_kbLayoutIndex = 0;
    QString m_kbLayouts = QStringLiteral("?");

    // Caps/Num lock from /sys/class/leds (not exposed by niri IPC)
    bool m_capsLock = false;
    bool m_numLock = false;
    QTimer m_ledPollTimer;
    QString m_capsLockPath;
    QString m_numLockPath;
};

} // namespace caelestia::niri
