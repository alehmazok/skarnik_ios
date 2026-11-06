# TestFlight with Xcode Cloud

TestFlight builds run on Xcode Cloud: 25 compute hours a month come with the Apple Developer Program, and
Apple manages signing, so no certificate or API key is stored anywhere and CI can never hit Apple's
development-certificate limit. Pull request tests and BrowserStack stay on GitHub Actions (`ci.yml`,
`browserstack.yml`), which are free for this public repo.

The only file in the repo is `ci_scripts/ci_post_clone.sh`: it writes the gitignored
`GoogleService-Info.plist` from a secret before the build. The workflow itself lives in App Store Connect.

## One-time setup (Aleh)

1. In Xcode, open `Skarnik.xcodeproj` → **Product → Xcode Cloud → Create Workflow**, product **Skarnik**.
   Grant Xcode Cloud access to `alehmazok/skarnik_ios` on GitHub when asked.
2. Edit the workflow:
   - **General**: name `TestFlight`; restrict editing to admins.
   - **Environment**: latest release Xcode. Add the environment variable `GOOGLE_SERVICE_INFO_PLIST`, value
     = the same base64 text as the GitHub secret, and tick **Secret**.
   - **Start Conditions**: remove the default branch condition and add **Manual Start** (branch `main`),
     so a build only runs when you start it. Add "Branch changes" on `main` instead if every merge should
     reach TestFlight.
   - **Actions**: **Archive**, platform iOS, scheme `Skarnik`, deployment preparation **TestFlight (Internal
     Testing Only)** or **TestFlight and App Store**.
   - **Post-Actions**: **TestFlight Internal Testing**, pick the internal group.
3. App Store Connect → **Apps → Skarnik → Xcode Cloud → Settings → Build Number**: set the next build
   number above the highest build already uploaded, so Xcode Cloud's numbers never collide.
4. Start the workflow once (Xcode → Report navigator → Cloud, or App Store Connect → Xcode Cloud → Start
   Build) and check the build reaches TestFlight.

## Notes

- Xcode Cloud sets `CFBundleVersion` from its own build counter (`CI_BUILD_NUMBER`); `MARKETING_VERSION`
  is still bumped by hand in the project.
- Unused hours do not roll over. One archive takes a few minutes, so 25 hours is far more than TestFlight needs.
- `testflight.yml` on GitHub stays as a fallback until Xcode Cloud has shipped a build; then it is removed
  with its secrets (`DEV_CERT_P12`, `DEV_CERT_PASSWORD`, `ASC_*`).
