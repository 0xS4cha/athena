return {
  name = 'Athena',
  developer = 'Unknow',
  version = '1.0',
  love = '11.5',
  output = 'dist',
  icon = 'assets/icon.png',
  identifier = 'com.athena.game',
  platforms = {'windows', 'macos', 'linux'},
  ignore = {
    'dist', 'build', 'tests', 'love-build', 'lib',
    'Makefile', 'Dockerfile', '.dockerignore', '.env', '.env.example', '.luarc.json',
    'build.lua', 'CODE_OF_CONDUCT.md', 'appimagetool.AppImage', 'athena', 'athena_server'
  }
}
