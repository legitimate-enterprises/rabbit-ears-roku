# Rabbit Ears for Roku
The Roku app for [Rabbit Ears](https://github.com/legitimate-enterprises/rabbit-ears),
a self-hosted open-source media server. It is for anyone who runs a Rabbit
Ears server or is invited to one.

------------------------------------------------------------------------
## How It Works
- A BrightScript and SceneGraph app. `make build` validates it with `bsc`
  and zips the sources as written into `build/rabbit-ears.zip`.
- The icons, splash screens and focus shapes are drawn by
  `scripts/images.mjs` at build time; no image is stored.
- The app talks only to a Rabbit Ears server, through that server's REST
  API. `openapi.yaml` is the server's spec at the release the app is built
  against, and a test fails when the app calls an operation the spec lacks.
  `make spec VERSION=<server version>` replaces it with another release's.
- `make run` sideloads the package to a Roku in developer mode.
- `make deploy` tags `roku-v<major_version>` once CI is green on `main`. The
  tag's release job signs the package on the developer-mode Roku that holds
  the signing key and attaches it to the tag's GitHub release.

Limitations: the signed package is uploaded to the Roku Developer Dashboard
by hand, and the release job needs a runner on that Roku's network.

------------------------------------------------------------------------
## Requirements
- Node LTS, `make` and `zip`.
- `make run`: a Roku in developer mode, as `ROKU_HOST` and `ROKU_PASSWORD`.
- `make deps` installs the rest.

------------------------------------------------------------------------
*End of README*
