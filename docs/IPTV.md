# Optional step: IPTV on the cleaned TV

Not part of the installer. Facts from the reference TV (LG C3, webOS 11.2, October 2026):

- **Kodi 21.0 (the only stable Kodi build for webOS) does not work on webOS 26 (11.2).** The firmware's audio path changed; Kodi logs
  `CAESinkALSA - snd_pcm_writei(-32) Broken pipe` and crashes when a stream starts. The fix exists only in Kodi 22 (RC1 since 2026-10-10,
  nightlies since mid-September 2026). Kodi's IPTV Simple Client also cannot browse Xtream movies/series and loads the whole EPG into RAM —
  with 50'000+ channels that alone exceeds the ~400 MB a 2 GB TV leaves to an app.
- **Recommended instead: [lennylxx/webos-iptv-player](https://github.com/lennylxx/webos-iptv-player)** (Apache-2.0). M3U and Xtream
  accounts, movies and series, XMLTV EPG, catch-up, native player (4K HEVC, HDR, Dolby passthrough), credentials stay on the TV.
  Large playlists are handled (streaming parser, EPG only for visible channels); on the reference TV 53'000 channels loaded with 220 MB RAM to spare.

## Install the player (root, IPK)

```bash
# on your computer
gh release download --repo lennylxx/webos-iptv-player --pattern '*.ipk' --pattern '*.manifest.json'
shasum -a 256 com.lennylxx.iptv_*_all.ipk        # compare with "ipkHash" in the manifest
scp -i ~/.ssh/webos_tv_root com.lennylxx.iptv_*_all.ipk root@<tv-ip>:/tmp/iptv.ipk
ssh -tt -i ~/.ssh/webos_tv_root root@<tv-ip> \
  "luna-send -i -f luna://com.webos.appInstallService/dev/install '{\"id\":\"com.lennylxx.iptv\",\"ipkUrl\":\"/tmp/iptv.ipk\",\"subscribe\":true}'"
```

Or add the project's repository URL in Homebrew Channel (see its README) and install from there.

## Configure

Open the app once. **Settings (Blue key) → Device Setup** shows a QR code / URL: configure the Xtream account or M3U URL from your phone
or computer on the same network; credentials never leave the TV. In **Xtream Accounts** pick *HLS* as live format if raw MPEG-TS over
HTTP stutters on webOS 26, and select only the live categories you use if memory gets tight.

Then put the player into your app row: add `com.lennylxx.iptv` to `config/order.txt` and run `sh /var/lib/webosbrew/cleantv/bin/order.sh`.

## Store IPTV apps

Most "IPTV" apps in the LG Content Store bind your playlist to the TV's MAC address through the vendor's web portal, keep the credentials
on the vendor's server (one of them restored a full account on a fresh install without being asked), charge a per-TV activation fee, and
ship analytics. If a tracking-free TV is the goal, prefer the open-source player above.
