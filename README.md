# GLOBE
Project "GLOBE", the ***G**lobal **L**iberation **O**f **B**rowsing and **E**ntertainment*, is an effort to improve the access to privacy-friendly frontends 
*(namely [Invidious,](https://invidious.io) [RedLib,](https://github.com/redlib-org/redlib) [SearXNG,](https://github.com/searxng/searxng)
and [BreezeWiki](https://breezewiki.com))* across the globe.
The results of this effort can be seen on [the official hosting list.](https://www.ggtyler.dev/other/frontends)

This git repo serves as the internal structure and setup used in the official servers. It's designed to be easily integrated into any server, while still 
allowing modifications for any changes necessary.

To start, simply run `scripts/init.sh`:

```sh
git clone https://github.com/ggtylerr/globe
cd globe
chmod +x scripts/init.sh
./scripts/init.sh
```

For the best results, use a debian-based distro, like Ubuntu.

## Frontends
Below is a list of frontends hosted, as well as any notes about their setup.

* [Invidious](https://invidious.io) *(port: 54301)*
  - Configured to use the latest patch, utilizing `poToken` and `visitorData`. Because of this, it is required to generate one before running Invidious. (One is generated for you when using `init.sh`.)
  - Configured to use unixfox's [performant configuration](https://docs.invidious.io/improve-public-instance/) (with the exception of http3-ytproxy, which is deprecated software and does not work) and pgbouncer.
* [Piped](https://docs.piped.video) *(port: 54302)*
  - This software is not expected to work on public instances yet.
* [Hyperpipe](https://codeberg.org/Hyperpipe/Hyperpipe) *(ports: 54303, 54304)*
  - This relies on the above Piped instance.
* [Poke](https://codeberg.org/ashley/poke) *(port: 54305)*
  - Due to issues relating to their Docker image, this service runs on bare metal.
* [RedLib](https://github.com/redlib-org/redlib) *(port: 54306)*
* [SafeTwitch](https://codeberg.org/SafeTwitch/safetwitch) *(ports: 54307, 54308)*
* [Dumb](https://github.com/rramiachraf/dumb) *(port: 54309)*
* [Breezewiki](https://gitdab.com/cadence/breezewiki) *(port: 54310)*
  - Docker image [courtesy of PussTheCat.](https://github.com/PussTheCat-org/docker-breezewiki-quay)
* [Cobalt](https://github.com/imputnet/cobalt) *(ports: 54311, 54312)*
* [SearXNG](https://docs.searxng.org/) *(port: 54313)*
* [LibreY](https://github.com/Ahwxorg/LibreY) *(port: 54314)*
* [SimpleTranslate](https://codeberg.org/ManeraKai/simplytranslate/) *(port: 54315)*
* [LibreTranslate](https://github.com/LibreTranslate/LibreTranslate) *(port: 54316)*
* [Lingva](https://github.com/TheDavidDelta/lingva-translate) *(port: 54317)*
* [Mozhi](https://codeberg.org/aryak/mozhi) *(port: 54318)*

## Additional Notes

While Project GLOBE is mostly complete, it was primarily designed around using a specific setup (Ubuntu, Nginx, Docker, etc.)
We currently do not have the means to support other configurations (such as a fully bare metal host, or using Caddy.) Currently, there is also no way to only do a
selection of frontends when using `init.sh`.

It should also be noted that due to the constantly changing nature of these services and the websites they proxy, they are not expected to
last forever and updates should be done whenever possible. Most docker containers should be updated automatically via [Watchtower](https://containrrr.dev/watchtower/)
(with the exception of SimplyTranslate, which has no hosted image and is built manually,) however, any config changes can be done over `update.sh`.

Since Poke is running over bare metal, it can be updated using the following:
```sh
cd services/poke
git pull
# Resolve any changes needed, since config.json is modified and it may be updated in the future
pm2 restart poke
```

## License
This project is licensed under [AGPL v3.](https://www.gnu.org/licenses/agpl-3.0.en.html) Several other repositories are used in this project and their license/s
are followed as best as possible. For any legal inquiries, [please contact the main author of this project, Tyler Flowers "ggtyler"](https://www.ggtyler.dev/social)