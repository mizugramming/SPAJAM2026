// 画面ごとの部品の位置と大きさ。値は画面の幅・高さに対する割合（0〜1）。
// Box(左, 上, 幅, 高さ, 文字の倍率) — 文字の倍率は省略すると1。
// Chromeの開発版では右下の「配置を編集」で四角を動かせる。決まったら「ファイル用にコピー」で
// このファイルの中身と置き換えて保存する。
// dart format off
import 'layout_tuner.dart';

const screenLayouts = <Screen, Map<String, Box>>{
  Screen.title: {
    'logo': Box(.07, .14, .66, .2),
    'tagline': Box(.07, .35, .66, .025),
    'catch': Box(.8, .1, .14, .4),
    'medal': Box(.12, .45, .76, .34),
    'start': Box(.056, .85, .888, .07),
  },
  Screen.select: {
    'header': Box(0, .01, .885, .065),
    'title': Box(.185, .135, .8, .045),
    'material-medal': Box(.085, .31, .835, .155),
    'material-kanji': Box(.09, .51, .845, .165),
  },
  Screen.voice: {
    'header': Box(.056, .011, .888, .046),
    'round': Box(.056, .068, .888, .03),
    'workpiece': Box(.056, .105, .888, .36),
    'title': Box(.056, .485, .888, .045),
    'body': Box(.056, .535, .888, .07),
    'chips': Box(.056, .615, .888, .045),
    'error': Box(.056, .665, .888, .05),
    'action': Box(.056, .725, .888, .065),
    'mode': Box(.056, .795, .888, .055),
  },
  Screen.ready: {
    'paper': Box(.018, .015, .964, .97),
    'round': Box(.09, .067, .8, .035),
    'title': Box(.09, .122, .82, .062),
    'body': Box(.09, .195, .82, .074),
    'error': Box(.08, .603, .84, .095),
    'workpiece': Box(.08, .716, .84, .108),
    'action': Box(.08, .848, .84, .084),
  },
  Screen.polishing: {
    'paper': Box(.018, .015, .964, .97),
    'round': Box(.09, .067, .8, .035),
    'title': Box(.09, .122, .82, .062),
    'timer': Box(.09, .197, .82, .048),
    'bar': Box(.09, .26, .82, .005),
    'error': Box(.08, .603, .84, .095),
    'workpiece': Box(.08, .716, .84, .108),
    'action': Box(.08, .848, .84, .084),
  },
  Screen.result: {
    'header': Box(.056, .011, .888, .046),
    'round': Box(.056, .068, .888, .03),
    'workpiece': Box(.056, .105, .888, .36),
    'title': Box(.056, .485, .888, .045),
    'body': Box(.056, .535, .888, .1),
    'action': Box(.056, .65, .888, .065),
  },
};
