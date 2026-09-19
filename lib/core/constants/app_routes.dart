import '../utils/date_key.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const space = '/space';
  static const starPlacementEditor = '/space/star-placement';
  static const constellation = '/constellation';
  static const constellationReveal = '/constellation-reveal';
  static const universe = '/universe';
  static const history = '/history';
  static String constellationOn(DateTime date) =>
      '$constellation?date=${dateKey(date)}';
  static String constellationRevealOn(DateTime date) =>
      '$constellationReveal?date=${dateKey(date)}';
}
