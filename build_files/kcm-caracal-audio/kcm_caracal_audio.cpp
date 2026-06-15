#include <KPluginFactory>
#include <KPluginMetaData>
#include <KQuickConfigModule>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>

class CaracalAudioKcm : public KQuickConfigModule {
  Q_OBJECT
  Q_PROPERTY(
      bool cpuPerformanceActive READ cpuPerformanceActive NOTIFY statusChanged)
  Q_PROPERTY(bool btMicMitigationActive READ btMicMitigationActive NOTIFY
                 statusChanged)
  Q_PROPERTY(bool virtualChannelsActive READ virtualChannelsActive NOTIFY
                 statusChanged)
  Q_PROPERTY(bool jackDbusActive READ jackDbusActive NOTIFY statusChanged)
  Q_PROPERTY(int midiBridgeType READ midiBridgeType NOTIFY
                 statusChanged) // 0: None, 1: A2J, 2: Native
  Q_PROPERTY(
      bool vstIsolationActive READ vstIsolationActive NOTIFY statusChanged)
  Q_PROPERTY(bool juceDxvkActive READ juceDxvkActive NOTIFY statusChanged)
  Q_PROPERTY(bool juceDesktopActive READ juceDesktopActive NOTIFY statusChanged)

public:
  explicit CaracalAudioKcm(QObject *parent, const KPluginMetaData &metaData)
      : KQuickConfigModule(parent, metaData) {
    refresh();
  }

  Q_INVOKABLE void refresh() {
    checkCpuPerformance();
    checkBtMicMitigation();
    checkVirtualChannels();
    checkJackDbus();
    checkMidiBridge();
    checkVstIsolation();
    checkJuceFixes();
    emit statusChanged();
  }

  bool cpuPerformanceActive() const { return m_cpuPerformanceActive; }
  bool btMicMitigationActive() const { return m_btMicMitigationActive; }
  bool virtualChannelsActive() const { return m_virtualChannelsActive; }
  bool jackDbusActive() const { return m_jackDbusActive; }
  int midiBridgeType() const { return m_midiBridgeType; }
  bool vstIsolationActive() const { return m_vstIsolationActive; }
  bool juceDxvkActive() const { return m_juceDxvkActive; }
  bool juceDesktopActive() const { return m_juceDesktopActive; }

signals:
  void statusChanged();

private:
  void checkCpuPerformance() {
    QProcess process;
    process.start(
        "sh",
        {"-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | "
               "sort -u"});
    process.waitForFinished();
    QString output = process.readAllStandardOutput().trimmed();
    m_cpuPerformanceActive = (output == "performance");
  }

  void checkBtMicMitigation() {
    m_btMicMitigationActive =
        QFile::exists("/etc/wireplumber/wireplumber.conf.d/"
                      "51-mitigate-annoying-profile-switch.conf");
  }

  void checkVirtualChannels() {
    QString path = QDir::homePath() +
                   "/.config/pipewire/pipewire.conf.d/virtual-channels.conf";
    m_virtualChannelsActive = QFile::exists(path);
  }

  void checkJackDbus() {
    QProcess process;
    process.start("systemctl",
                  {"--user", "is-active", "caracal-jackdbus.service"});
    process.waitForFinished();
    m_jackDbusActive = (process.exitCode() == 0);
  }

  void checkMidiBridge() {
    // Check A2J
    QProcess process;
    process.start("systemctl",
                  {"--user", "is-active", "caracal-a2jmidid.service"});
    process.waitForFinished();
    if (process.exitCode() == 0) {
      m_midiBridgeType = 1;
      return;
    }

    // Check Native
    QString path = QDir::homePath() +
                   "/.config/pipewire/pipewire.conf.d/legacy-midi-bridge.conf";
    if (QFile::exists(path)) {
      m_midiBridgeType = 2;
      return;
    }

    m_midiBridgeType = 0;
  }

  void checkVstIsolation() {
    QString path = QDir::homePath() + "/.config/REAPER/reaper-vstplugins64.ini";
    if (!QFile::exists(path)) {
      m_vstIsolationActive = false;
      return;
    }

    QFile file(path);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
      QTextStream in(&file);
      QString content = in.readAll();
      m_vstIsolationActive = content.contains("<BRG2>");
      file.close();
    } else {
      m_vstIsolationActive = false;
    }
  }

  void checkJuceFixes() {
    QString dxvkPath = QDir::homePath() + "/.config/caracal/dxvk-juce.conf";
    m_juceDxvkActive = QFile::exists(dxvkPath);

    // Registry check for desktop is heavier maybe just skip for now or use a
    // quick grep if possible but since we want to be accurate:
    m_juceDesktopActive = false; // Default to false if we can't easily check

    QProcess wineProcess;
    wineProcess.start(
        "wine",
        {"reg", "query", "HKCU\\Software\\Wine\\X11 Driver", "/v", "Desktop"});
    wineProcess.waitForFinished(1000); // 1s timeout
    if (wineProcess.exitCode() == 0) {
      m_juceDesktopActive =
          wineProcess.readAllStandardOutput().contains("CaracalStudio");
    }
  }

  bool m_cpuPerformanceActive = false;
  bool m_btMicMitigationActive = false;
  bool m_virtualChannelsActive = false;
  bool m_jackDbusActive = false;
  int m_midiBridgeType = 0;
  bool m_vstIsolationActive = false;
  bool m_juceDxvkActive = false;
  bool m_juceDesktopActive = false;
};

K_PLUGIN_CLASS_WITH_JSON(CaracalAudioKcm, "kcm_caracal_audio.json")

#include "kcm_caracal_audio.moc"
