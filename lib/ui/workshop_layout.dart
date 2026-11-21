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
    'start': Box(.056, .85, .888, .085),
  },
  Screen.select: {
    'header': Box(0, .01, .885, .065),
    'back': Box(.01, .065, .345, .055),
    'title': Box(.185, .135, .8, .045),
    'heading': Box(.056, .215, .888, .05),
    'pager': Box(0, .27, 1, .44),
    'confirm': Box(.056, .75, .888, .082),
  },
  Screen.voice: {
    'header': Box(.056, .011, .888, .046),
    'back': Box(.01, .065, .345, .055),
    'round': Box(.03, .14, .965, .055),
    'workpiece': Box(0, .2, 1, .405),
    'title': Box(.056, .615, .888, .055),
    'chips': Box(.056, .916, .888, .066),
    'error': Box(.056, .67, .888, .066),
    'action': Box(.25, .742, .5, .15),
  },
  Screen.ready: {
    'paper': Box(.018, .69, .964, .3),
    'round': Box(.055, .017, .89, .038),
    'workpiece': Box(.025, .059, .95, .528),
    'title': Box(.055, .6, .89, .065),
    'error': Box(.055, .79, .89, .12),
    'action': Box(.255, .37, .49, .086),
  },
  Screen.polishing: {
    'paper': Box(.018, .69, .964, .3),
    'round': Box(.055, .017, .89, .038),
    'workpiece': Box(.025, .059, .95, .528),
    'cue': Box(0, .245, 1, .132),
    'timer': Box(.055, .602, .89, .06),
    'bar': Box(.055, .675, .89, .004),
    'error': Box(.07, .788, .86, .084),
    'action': Box(.24, .885, .52, .076),
  },
  Screen.result: {
    'header': Box(.056, .011, .888, .046),
    'round': Box(.02, .12, .965, .055),
    'workpiece': Box(0, .175, 1, .45),
    'title': Box(.056, .64, .888, .045),
    'body': Box(.056, .69, .888, .09),
    'action': Box(.056, .78, .888, .08),
    'home': Box(.056, .87, .888, .06),
  },
};
