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
    'back': Box(.01, .065, .345, .055),
    'title': Box(.185, .135, .8, .045),
    'heading': Box(.056, .215, .888, .05),
    'pager': Box(0, .27, 1, .44),
    'confirm': Box(.056, .75, .888, .07),
  },
  Screen.voice: {
    'header': Box(.056, .011, .888, .046),
    'back': Box(.01, .065, .345, .055),
    'round': Box(.03, .14, .965, .055),
    'workpiece': Box(0, .205, 1, .45),
    'title': Box(.06, .655, .888, .045),
    'chips': Box(.11, .925, .888, .045),
    'error': Box(.06, .72, .888, .05),
    'action': Box(.265, .755, .5, .13),
    'mode': Box(.055, .885, .888, .05),
  },
  Screen.ready: {
    'header': Box(.056, .011, .888, .046),
    'round': Box(.02, .12, .965, .055),
    'workpiece': Box(0, .11, 1, .7),
    'title': Box(.025, .69, .888, .045),
    'error': Box(.056, .71, .888, .05),
    'action': Box(.056, .775, .888, .065),
  },
  Screen.polishing: {
    'header': Box(.056, .011, .888, .046),
    'round': Box(.02, .12, .965, .055),
    'workpiece': Box(0, .11, 1, .7),
    'timer': Box(.02, .7, .93, .04),
    'bar': Box(.03, .75, .97, .01),
    'error': Box(.056, .765, .888, .05),
    'action': Box(.056, .835, .888, .065),
  },
  Screen.result: {
    'header': Box(.056, .011, .888, .046),
    'round': Box(.02, .12, .965, .055),
    'workpiece': Box(0, .175, 1, .45),
    'title': Box(.056, .64, .888, .045),
    'body': Box(.056, .69, .888, .09),
    'action': Box(.056, .79, .888, .065),
    'home': Box(.056, .87, .888, .06),
  },
};
