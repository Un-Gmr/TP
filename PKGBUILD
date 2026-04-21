pkgname=tp
pkgver=1.8
pkgrel=1
pkgdesc="Terminal music player using mpv"
arch=('any')
url="https://github.com/Un-Gmr/TP"
license=('custom')

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
  install -Dm755 "$srcdir/play.sh" "$pkgdir/usr/bin/tp-scripts/play"
  install -Dm755 "$srcdir/playlist.sh" "$pkgdir/usr/bin/tp-scripts/playlist"
  install -Dm755 "$srcdir/playctl.sh" "$pkgdir/usr/bin/tp-scripts/playctl"
  install -Dm755 "$srcdir/terminal_player_mpris.py" "$pkgdir/usr/bin/tp-scripts/terminal-player-mpris"
  install -Dm755 "$srcdir/tp" "$pkgdir/usr/bin/tp"
}
