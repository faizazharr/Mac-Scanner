# Downloading MacScanner (no developer tools needed)

This guide is for anyone who just wants to **run** MacScanner — no Xcode, no
Swift, no building from source.

## 1. Download

Go to the [Releases page](../../releases) of this repository and download
the newest **`MacScanner.zip`** under "Assets".

## 2. Unzip and move it to Applications

Double-click the zip to extract `MacScanner.app`, then drag it into your
`Applications` folder.

## 3. First launch

macOS will refuse to open it the normal way the first time, with a message
like *"MacScanner can't be opened because it is from an unidentified
developer."* This is expected — MacScanner isn't notarized by Apple (that
requires a paid Apple Developer account), which is normal for a free,
open-source Mac app. To open it anyway:

1. **Right-click** (or Control-click) `MacScanner.app` in Applications.
2. Choose **Open**.
3. Click **Open** again in the dialog that appears.

You only need to do this once — after that, it opens normally like any other app.

## 4. First scan

The first time you open a folder (or the Recommendations/Performance tabs),
macOS may ask permission to access your Documents, Downloads, or Desktop
folder. Allow it — MacScanner only reads folder sizes, it never sends
anything anywhere, and every delete goes through a confirmation and lands in
the Trash (never permanent).

## Something not working?

Open an [issue](../../issues) on this repository describing what happened —
include your macOS version (Apple menu ▸ About This Mac).

---

Want to build it yourself instead, or contribute changes? See the main
[README](README.md#building--running).
