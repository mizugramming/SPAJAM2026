{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Keep fallback font requests on this origin, including for user-entered text.
    // Japanese and Latin fonts are bundled in the app's font manifest.
    fontFallbackBaseUrl: 'assets/font-fallbacks/',
  },
});
