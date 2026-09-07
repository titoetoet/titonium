// Isolated synthetic MPRIS endpoint: no application or real playback is controlled.
#include <QCoreApplication>
#include <QtDBus>
#include <QTimer>
#include <cstdio>
using MetadataList = QList<QVariantMap>;
class Player : public QDBusVirtualObject {
public:
 bool enabled=false; QString state="Playing";
 QVariantMap metadata(QString id="/track/one") { return {{"mpris:trackid",QVariant::fromValue(QDBusObjectPath(id))},{"xesam:title",id.endsWith("one")?"Current fixture":"Next fixture"},{"xesam:artist",QStringList{"Test artist"}},{"mpris:length",qlonglong(200000000)}}; }
 QVariantMap properties(QString iface) {
  if (iface.endsWith("TrackList")) return {{"Tracks",QVariant::fromValue(QList<QDBusObjectPath>{QDBusObjectPath("/track/one"),QDBusObjectPath("/track/two")})},{"CanEditTracks",false}};
  if (iface.endsWith("Player")) return {{"PlaybackStatus",state},{"Metadata",metadata()},{"CanControl",true},{"CanPlay",enabled},{"CanPause",enabled},{"CanGoNext",enabled},{"CanGoPrevious",enabled},{"CanSeek",enabled},{"Position",qlonglong(20000000)},{"Rate",1.0},{"MinimumRate",1.0},{"MaximumRate",1.0},{"Volume",1.0},{"LoopStatus","None"},{"Shuffle",false}};
  return {{"Identity","Music test"},{"HasTrackList",true},{"CanRaise",false},{"CanQuit",false},{"SupportedUriSchemes",QStringList{}},{"SupportedMimeTypes",QStringList{}}};
 }
 QString introspect(const QString &) const override { return "<interface name=\"org.mpris.MediaPlayer2.TrackList\"><method name=\"GetTracksMetadata\"><arg type=\"ao\" direction=\"in\"/><arg type=\"aa{sv}\" direction=\"out\"/></method></interface>"; }
 void changed() {
  auto m=QDBusMessage::createSignal("/org/mpris/MediaPlayer2","org.freedesktop.DBus.Properties","PropertiesChanged");
  m << "org.mpris.MediaPlayer2.Player" << QVariantMap{{"CanPlay",enabled},{"CanPause",enabled},{"CanGoNext",enabled},{"CanGoPrevious",enabled},{"CanSeek",enabled}} << QStringList{};
  QDBusConnection::sessionBus().send(m);
 }
 bool handleMessage(const QDBusMessage &m,const QDBusConnection &bus) override {
  QList<QVariant> reply;
  if(m.interface()=="org.freedesktop.DBus.Properties") {
   auto p=properties(m.arguments()[0].toString());
   if(m.member()=="GetAll") reply << p;
   else if(m.member()=="Get") reply << QVariant::fromValue(QDBusVariant(p.value(m.arguments()[1].toString())));
   else { std::puts("CALL Set"); std::fflush(stdout); }
  } else if(m.member()=="GetTracksMetadata") reply << QVariant::fromValue(MetadataList{metadata("/track/two")});
  else { std::printf("CALL %s\n",qPrintable(m.member())); std::fflush(stdout); }
  bus.send(m.createReply(reply)); return true;
 }
};
int main(int argc,char **argv) {
 QCoreApplication app(argc,argv); qDBusRegisterMetaType<MetadataList>(); qDBusRegisterMetaType<QList<QDBusObjectPath>>();
 Player p; auto bus=QDBusConnection::sessionBus();
 if(!bus.registerService("org.mpris.MediaPlayer2.titonium_fixture") || !bus.registerVirtualObject("/org/mpris/MediaPlayer2",&p)) return 1;
 QTimer::singleShot(1800,[&]{p.enabled=true;p.changed();});
 return app.exec();
}
