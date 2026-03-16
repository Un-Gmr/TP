pkgname=tp
pkgver=1.2
pkgrel=1
pkgdesc=""
arch=('any')
url=""
license=('NONE')

depends=(
  mpv
  yt-dlp
  jq
  curl
  imagemagick
  figlet
  jp2a
  socat
  python
  python-pip
)

source=(
  play.sh
  playlist.sh
  playctl.sh
  terminal_player_mpris.py
  tp
)

sha256sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')

prepare() {
  python -m pip install --no-deps --prefix="$pkgdir/usr" syncedlyrics dbus-next
}

package() {
  install -Dm755 "$srcdir/play.sh" "$pkgdir/usr/local/bin/tp-scripts/play"
  install -Dm755 "$srcdir/playlist.sh" "$pkgdir/usr/local/bin/tp-scripts/playlist"

  [ -f "$srcdir/playctl.sh" ] && install -Dm755 "$srcdir/playctl.sh" "$pkgdir/usr/local/bin/tp-scripts/playctl" || echo "WARNING: playctl.sh missing"
  [ -f "$srcdir/terminal_player_mpris.py" ] && install -Dm755 "$srcdir/terminal_player_mpris.py" "$pkgdir/usr/local/bin/tp-scripts/terminal-player-mpris" || echo "WARNING: terminal_player_mpris.py missing"
  [ -f "$srcdir/tp" ] && install -Dm755 "$srcdir/tp" "$pkgdir/usr/local/bin/tp" || echo "WARNING: tp wrapper missing"
}
