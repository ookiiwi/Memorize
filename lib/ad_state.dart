import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdState {
  AdState(this.initialization);

  Future<InitializationStatus> initialization;

  String get interstitialId => "ca-app-pub-3940256099942544/1033173712";
  String get bannerId => "ca-app-pub-3940256099942544/6300978111";
}
