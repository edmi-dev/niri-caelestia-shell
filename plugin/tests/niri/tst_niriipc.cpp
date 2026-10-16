#include <niri/niriipc.hpp>

#include <qdir.h>
#include <qfile.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qsignalspy.h>
#include <qtest.h>

#include <algorithm>

using caelestia::niri::NiriIpc;

namespace {

QString fixturesRoot() {
    return QStringLiteral(CAELESTIA_NIRI_FIXTURES_DIR);
}

QJsonValue readJson(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qFatal("cannot open fixture %s", qPrintable(path));
    }
    // `niri msg --json` may print a top-level scalar (e.g. `null` for focused-window with no focus),
    // which QJsonDocument can't parse directly, so wrap it in an array.
    return QJsonDocument::fromJson('[' + file.readAll() + ']').array().at(0);
}

// `niri msg --json <query>` prints the unwrapped reply; NiriIpc::applyResponse expects the wrapped "Ok" value.
void loadSnapshot(NiriIpc& ipc, const QString& dir, const QString& suffix = {}) {
    const auto load = [&](const QString& file, const QString& key) {
        ipc.applyResponse({ { key, readJson(dir + u'/' + file + suffix + QStringLiteral(".json")) } });
    };
    load(QStringLiteral("workspaces"), QStringLiteral("Workspaces"));
    load(QStringLiteral("windows"), QStringLiteral("Windows"));
    load(QStringLiteral("focused-window"), QStringLiteral("FocusedWindow"));
    load(QStringLiteral("outputs"), QStringLiteral("Outputs"));
    load(QStringLiteral("keyboard-layouts"), QStringLiteral("KeyboardLayouts"));
}

int replayEvents(NiriIpc& ipc, const QString& dir) {
    QFile file(dir + QStringLiteral("/event-stream.jsonl"));
    if (!file.open(QIODevice::ReadOnly)) {
        return 0;
    }
    int count = 0;
    while (!file.atEnd()) {
        const auto line = file.readLine().trimmed();
        if (line.isEmpty()) {
            continue;
        }
        ipc.processEvent(QJsonDocument::fromJson(line).object());
        ++count;
    }
    return count;
}

QVariantMap workspaceById(const NiriIpc& ipc, int id) {
    const auto list = ipc.workspaces();
    for (const auto& v : list) {
        if (v.toMap().value(QStringLiteral("id")).toInt() == id) {
            return v.toMap();
        }
    }
    return {};
}

QList<int> ids(const QVariantList& list) {
    QList<int> res;
    for (const auto& v : list) {
        res.append(v.toMap().value(QStringLiteral("id")).toInt());
    }
    return res;
}

// Window ids per workspace in scrolling-layout order (column, then tile), as niri reports them.
QMap<int, QList<int>> windowOrder(const QJsonArray& windows) {
    QList<QJsonObject> sorted;
    for (const auto& v : windows) {
        sorted.append(v.toObject());
    }
    const auto key = [](const QJsonObject& w) {
        const auto pos = w.value(QStringLiteral("layout")).toObject().value(QStringLiteral("pos_in_scrolling_layout"));
        const auto arr = pos.toArray();
        return std::make_pair(arr.size() > 0 ? arr.at(0).toInt() : 0, arr.size() > 1 ? arr.at(1).toInt() : 0);
    };
    std::stable_sort(sorted.begin(), sorted.end(), [&](const auto& a, const auto& b) {
        return key(a) < key(b);
    });
    QMap<int, QList<int>> res;
    for (const auto& w : std::as_const(sorted)) {
        res[w.value(QStringLiteral("workspace_id")).toInt()].append(w.value(QStringLiteral("id")).toInt());
    }
    return res;
}

QMap<int, QList<int>> windowOrder(const QVariantList& windows) {
    QMap<int, QList<int>> res;
    for (const auto& v : windows) {
        const auto w = v.toMap();
        res[w.value(QStringLiteral("workspace_id")).toInt()].append(w.value(QStringLiteral("id")).toInt());
    }
    return res;
}

} // namespace

class TestNiriIpc : public QObject {
    Q_OBJECT

private slots:
    void snapshot();
    void workspaceActivatedUnfocusedOutput();
    void workspaceActivatedFocused();
    void focusedWindowClosed();
    void windowLayoutsReorder();
    void keyboardLayoutSwitched();
    void workspaceActiveWindowChanged();
    void configLoaded();
    void fullscreenFixture();
    void fullscreenInactiveWorkspace();
    void actionPayload_data();
    void actionPayload();
    void replayFixtures_data();
    void replayFixtures();

private:
    const QString m_basic = fixturesRoot() + QStringLiteral("/synthetic-basic");
};

void TestNiriIpc::snapshot() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);

    // Workspaces sorted by idx (stable across outputs), focus from is_focused
    QCOMPARE(ipc.workspaces().size(), 5);
    QCOMPARE(ipc.focusedWorkspaceId(), 1);
    QCOMPARE(ipc.focusedMonitorName(), QStringLiteral("eDP-1"));
    QCOMPARE(ids(ipc.currentOutputWorkspaces()), (QList<int>{ 1, 2, 3 }));
    QCOMPARE(ipc.getWorkspaceIdxById(5), 2);

    // Windows sorted by pos_in_scrolling_layout; floating (null pos) first
    QCOMPARE(ids(ipc.getWindowsByWorkspaceId(1)), (QList<int>{ 11, 14, 10 }));
    QCOMPARE(ids(ipc.getActiveWorkspaceWindows()), (QList<int>{ 11, 14, 10 }));
    QCOMPARE(ipc.focusedWindowId(), QStringLiteral("10"));
    QCOMPARE(ipc.focusedWindowTitle(), QStringLiteral("Mozilla Firefox"));
    QCOMPARE(ipc.focusedWindowClass(), QStringLiteral("firefox"));

    const auto hasWindows = ipc.workspaceHasWindows();
    QCOMPARE(hasWindows.value(QStringLiteral("1")).toBool(), true);
    QCOMPARE(hasWindows.value(QStringLiteral("3")).toBool(), false);

    QCOMPARE(ipc.outputs().keys(), (QStringList{ QStringLiteral("HDMI-A-1"), QStringLiteral("eDP-1") }));

    QCOMPARE(ipc.kbLayouts(), QStringLiteral("English (US),Russian"));
    QCOMPARE(ipc.kbLayoutIndex(), 0);
    QCOMPARE(ipc.kbLayout(), QStringLiteral("en"));
    QCOMPARE(ipc.defaultKbLayout(), QStringLiteral("English (US)"));
}

void TestNiriIpc::workspaceActivatedUnfocusedOutput() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);
    QSignalSpy spy(&ipc, &NiriIpc::workspacesChanged);

    ipc.processEvent({ { QStringLiteral("WorkspaceActivated"),
        QJsonObject{ { QStringLiteral("id"), 5 }, { QStringLiteral("focused"), false } } } });

    QCOMPARE(spy.count(), 1);
    QCOMPARE(workspaceById(ipc, 5).value(QStringLiteral("is_active")).toBool(), true);
    QCOMPARE(workspaceById(ipc, 4).value(QStringLiteral("is_active")).toBool(), false);
    // Other output untouched, focus unchanged
    QCOMPARE(workspaceById(ipc, 1).value(QStringLiteral("is_active")).toBool(), true);
    QCOMPARE(workspaceById(ipc, 1).value(QStringLiteral("is_focused")).toBool(), true);
    QCOMPARE(ipc.focusedWorkspaceId(), 1);
    QCOMPARE(ipc.focusedMonitorName(), QStringLiteral("eDP-1"));
}

void TestNiriIpc::workspaceActivatedFocused() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);

    ipc.processEvent({ { QStringLiteral("WorkspaceActivated"),
        QJsonObject{ { QStringLiteral("id"), 4 }, { QStringLiteral("focused"), true } } } });

    QCOMPARE(ipc.focusedWorkspaceId(), 4);
    QCOMPARE(ipc.focusedMonitorName(), QStringLiteral("HDMI-A-1"));
    QCOMPARE(ids(ipc.currentOutputWorkspaces()), (QList<int>{ 4, 5 }));
    // Focus is global, activity is per output
    QCOMPARE(workspaceById(ipc, 1).value(QStringLiteral("is_focused")).toBool(), false);
    QCOMPARE(workspaceById(ipc, 1).value(QStringLiteral("is_active")).toBool(), true);
    QCOMPARE(workspaceById(ipc, 4).value(QStringLiteral("is_focused")).toBool(), true);
}

void TestNiriIpc::focusedWindowClosed() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);

    ipc.processEvent({ { QStringLiteral("WindowClosed"), QJsonObject{ { QStringLiteral("id"), 10 } } } });

    QCOMPARE(ipc.windows().size(), 4);
    QCOMPARE(ipc.focusedWindowId(), QString());
    QCOMPARE(ipc.focusedWindowIndex(), -1);
    QCOMPARE(ipc.focusedWindowClass(), QStringLiteral("Desktop"));
}

void TestNiriIpc::windowLayoutsReorder() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);

    const auto layout = [](int col, int tile) {
        return QJsonObject{ { QStringLiteral("pos_in_scrolling_layout"), QJsonArray{ col, tile } } };
    };
    ipc.processEvent({ { QStringLiteral("WindowLayoutsChanged"),
        QJsonObject{ { QStringLiteral("changes"),
            QJsonArray{ QJsonArray{ 10, layout(1, 1) }, QJsonArray{ 11, layout(2, 1) }, QJsonArray{ 14, layout(2, 2) } } } } } });

    QCOMPARE(ids(ipc.getWindowsByWorkspaceId(1)), (QList<int>{ 10, 11, 14 }));
    // Focus follows the window, not the row
    QCOMPARE(ipc.focusedWindowId(), QStringLiteral("10"));
    QCOMPARE(ipc.focusedWindow().value(QStringLiteral("id")).toInt(), 10);
}

void TestNiriIpc::keyboardLayoutSwitched() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);
    QSignalSpy spy(&ipc, &NiriIpc::keyboardChanged);

    ipc.processEvent({ { QStringLiteral("KeyboardLayoutSwitched"), QJsonObject{ { QStringLiteral("idx"), 1 } } } });
    QCOMPARE(ipc.kbLayoutIndex(), 1);
    QCOMPARE(ipc.kbLayout(), QStringLiteral("ru"));
    QCOMPARE(spy.count(), 1);

    // Same or out-of-range index: no change, no signal
    ipc.processEvent({ { QStringLiteral("KeyboardLayoutSwitched"), QJsonObject{ { QStringLiteral("idx"), 1 } } } });
    ipc.processEvent({ { QStringLiteral("KeyboardLayoutSwitched"), QJsonObject{ { QStringLiteral("idx"), 7 } } } });
    QCOMPARE(ipc.kbLayoutIndex(), 1);
    QCOMPARE(spy.count(), 1);
}

void TestNiriIpc::workspaceActiveWindowChanged() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);
    const auto event = [](const QJsonValue& win) {
        return QJsonObject{ { QStringLiteral("WorkspaceActiveWindowChanged"),
            QJsonObject{ { QStringLiteral("workspace_id"), 1 }, { QStringLiteral("active_window_id"), win } } } };
    };

    ipc.processEvent(event(11));
    QCOMPARE(workspaceById(ipc, 1).value(QStringLiteral("active_window_id")).toInt(), 11);
    ipc.processEvent(event(QJsonValue::Null));
    QVERIFY(workspaceById(ipc, 1).value(QStringLiteral("active_window_id")).isNull());
}

void TestNiriIpc::configLoaded() {
    NiriIpc ipc(false, nullptr);
    QSignalSpy spy(&ipc, &NiriIpc::configLoaded);

    // Fixture: one ConfigLoaded on connect, one after `niri msg action load-config-file`
    replayEvents(ipc, fixturesRoot() + QStringLiteral("/config-reload"));
    QCOMPARE(spy.count(), 2);
    QCOMPARE(spy.at(1).at(0).toBool(), false);

    ipc.processEvent({ { QStringLiteral("ConfigLoaded"), QJsonObject{ { QStringLiteral("failed"), true } } } });
    QCOMPARE(spy.count(), 3);
    QCOMPARE(spy.at(2).at(0).toBool(), true);
}

void TestNiriIpc::fullscreenFixture() {
    const auto dir = fixturesRoot() + QStringLiteral("/fullscreen");
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, dir);
    QSignalSpy spy(&ipc, &NiriIpc::fullscreenChanged);
    QVERIFY(ipc.fullscreenOutputs().isEmpty());
    QVERIFY(!ipc.hasFullscreen(QStringLiteral("winit")));

    // Real fullscreen: window_size == output logical size
    loadSnapshot(ipc, dir, QStringLiteral(".fullscreen"));
    QCOMPARE(ipc.fullscreenOutputs(), QStringList{ QStringLiteral("winit") });
    QVERIFY(ipc.hasFullscreen(QStringLiteral("winit")));
    QVERIFY(ipc.isWindowFullscreen(ipc.focusedWindowId().toLongLong()));
    QCOMPARE(spy.count(), 1);

    // Windowed fullscreen is invisible to IPC
    loadSnapshot(ipc, dir, QStringLiteral(".windowed-fullscreen"));
    QVERIFY(ipc.fullscreenOutputs().isEmpty());
    QCOMPARE(spy.count(), 2);

    // Event replay: on and off again
    NiriIpc replay(false, nullptr);
    loadSnapshot(replay, dir);
    QSignalSpy replaySpy(&replay, &NiriIpc::fullscreenChanged);
    replayEvents(replay, dir);
    QCOMPARE(replaySpy.count(), 2);
    QVERIFY(replay.fullscreenOutputs().isEmpty());
}

void TestNiriIpc::fullscreenInactiveWorkspace() {
    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, m_basic);
    const auto sized = [](int w, int h) {
        return QJsonObject{ { QStringLiteral("window_size"), QJsonArray{ w, h } } };
    };

    // Window 12 is on workspace 2 (inactive on eDP-1, logical 1536x960)
    ipc.processEvent({ { QStringLiteral("WindowLayoutsChanged"),
        QJsonObject{ { QStringLiteral("changes"), QJsonArray{ QJsonArray{ 12, sized(1536, 960) } } } } } });
    QVERIFY(ipc.isWindowFullscreen(12));
    QVERIFY(!ipc.hasFullscreen(QStringLiteral("eDP-1")));

    // Activating its workspace makes the output fullscreen
    ipc.processEvent({ { QStringLiteral("WorkspaceActivated"),
        QJsonObject{ { QStringLiteral("id"), 2 }, { QStringLiteral("focused"), true } } } });
    QVERIFY(ipc.hasFullscreen(QStringLiteral("eDP-1")));
    QVERIFY(!ipc.hasFullscreen(QStringLiteral("HDMI-A-1")));
}

void TestNiriIpc::actionPayload_data() {
    QTest::addColumn<QString>("name");
    QTest::addColumn<QVariantList>("args");
    QTest::addColumn<QByteArray>("expected");

    QTest::newRow("no args") << QStringLiteral("focus-workspace-up") << QVariantList()
                             << QByteArray(R"({"Action":{"FocusWorkspaceUp":{}}})");
    QTest::newRow("close focused") << QStringLiteral("close-window") << QVariantList()
                                   << QByteArray(R"({"Action":{"CloseWindow":{"id":null}}})");
    QTest::newRow("window by id") << QStringLiteral("focus-window") << QVariantList{ QStringLiteral("--id"), 12 }
                                  << QByteArray(R"({"Action":{"FocusWindow":{"id":12}}})");
    QTest::newRow("workspace by id") << QStringLiteral("focus-workspace") << QVariantList{ QStringLiteral("--id"), 5 }
                                     << QByteArray(R"({"Action":{"FocusWorkspace":{"reference":{"Id":5}}}})");
    QTest::newRow("workspace by index") << QStringLiteral("focus-workspace") << QVariantList{ 2 }
                                        << QByteArray(R"({"Action":{"FocusWorkspace":{"reference":{"Index":2}}}})");
    QTest::newRow("move window by id")
        << QStringLiteral("move-window-to-workspace") << QVariantList{ QStringLiteral("--id"), 4 }
        << QByteArray(R"({"Action":{"MoveWindowToWorkspace":{"focus":true,"reference":{"Id":4},"window_id":null}}})");
}

void TestNiriIpc::actionPayload() {
    QFETCH(QString, name);
    QFETCH(QVariantList, args);
    QFETCH(QByteArray, expected);

    // Compare as JSON values, key order is not significant
    QCOMPARE(QJsonDocument::fromJson(NiriIpc::actionPayload(name, args)), QJsonDocument::fromJson(expected));
}

// Every fixture scenario: snapshot + replayed event stream must reproduce the *.after.json snapshot.
void TestNiriIpc::replayFixtures_data() {
    QTest::addColumn<QString>("dir");

    const QDir root(fixturesRoot());
    const auto entries = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto& entry : entries) {
        const auto dir = root.filePath(entry);
        if (QFile::exists(dir + QStringLiteral("/workspaces.after.json"))) {
            QTest::newRow(qPrintable(entry)) << dir;
        }
    }
}

void TestNiriIpc::replayFixtures() {
    QFETCH(QString, dir);

    NiriIpc ipc(false, nullptr);
    loadSnapshot(ipc, dir);
    replayEvents(ipc, dir);

    const auto afterWs = readJson(dir + QStringLiteral("/workspaces.after.json")).toArray();
    QCOMPARE(ipc.workspaces().size(), afterWs.size());
    for (const auto& v : afterWs) {
        const auto expected = v.toObject();
        const auto id = expected.value(QStringLiteral("id")).toInt();
        const auto actual = workspaceById(ipc, id);
        QVERIFY2(!actual.isEmpty(), qPrintable(QStringLiteral("workspace %1 missing").arg(id)));
        for (const auto& field : { QStringLiteral("output"), QStringLiteral("idx"), QStringLiteral("is_active"),
                 QStringLiteral("is_focused"), QStringLiteral("active_window_id") }) {
            QVERIFY2(actual.value(field) == expected.value(field).toVariant(),
                qPrintable(QStringLiteral("workspace %1 field %2").arg(id).arg(field)));
        }
        if (expected.value(QStringLiteral("is_focused")).toBool()) {
            QCOMPARE(ipc.focusedWorkspaceId(), id);
            QCOMPARE(ipc.focusedMonitorName(), expected.value(QStringLiteral("output")).toString());
        }
    }

    const auto afterWin = readJson(dir + QStringLiteral("/windows.after.json")).toArray();
    QCOMPARE(windowOrder(ipc.windows()), windowOrder(afterWin));

    const auto afterFocused = readJson(dir + QStringLiteral("/focused-window.after.json"));
    const auto expectedFocus =
        afterFocused.isObject() ? QString::number(afterFocused.toObject().value(QStringLiteral("id")).toInteger()) : QString();
    QCOMPARE(ipc.focusedWindowId(), expectedFocus);

    const auto afterKb = readJson(dir + QStringLiteral("/keyboard-layouts.after.json")).toObject();
    QCOMPARE(ipc.kbLayoutIndex(), afterKb.value(QStringLiteral("current_idx")).toInt());
    QCOMPARE(ipc.kbLayoutsArray().size(), afterKb.value(QStringLiteral("names")).toArray().size());
}

QTEST_GUILESS_MAIN(TestNiriIpc)
#include "tst_niriipc.moc"
