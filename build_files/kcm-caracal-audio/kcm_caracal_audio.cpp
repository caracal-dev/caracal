#include <KPluginFactory>
#include <KPluginMetaData>
#include <KQuickConfigModule>

class CaracalAudioKcm : public KQuickConfigModule
{
    Q_OBJECT

public:
    explicit CaracalAudioKcm(QObject *parent, const KPluginMetaData &metaData)
        : KQuickConfigModule(parent, metaData)
    {
    }
};

K_PLUGIN_CLASS_WITH_JSON(CaracalAudioKcm, "kcm_caracal_audio.json")

#include "kcm_caracal_audio.moc"
