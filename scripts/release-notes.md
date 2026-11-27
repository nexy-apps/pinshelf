## ダウンロードと開き方

1. 下の `Pinshelf-<版>.dmg` をダウンロードして開き、`Pinshelf` を `Applications`（アプリケーションフォルダ）へドラッグします（`.zip` は展開して `Pinshelf.app` を入れる形です。中身は同じ）
2. 初めて開くと、「"Pinshelf.app"は開いていません」（Apple はマルウェアが含まれていないことを検証できませんでした）と止められます（Apple の公証を受けていないため）。**「完了」を押してください**（「ゴミ箱に入れる」は押さない）。そのあと、次のどちらかで開けます
   - システム設定 →「プライバシーとセキュリティ」の下の方にある「このまま開く」を押し（パスワードか Touch ID を聞かれます）、もう一度 Pinshelf を開く
   - ターミナルで `xattr -dr com.apple.quarantine /Applications/Pinshelf.app` を実行してから開く

   一度開けば、次からは止められません
3. メニューバーに Pinshelf のアイコンが出ます。ファイルをドラッグし始めると、画面の端に棚が出ます（出し方は、メニューバーの「設定…」で変えられます）

入れたあとは、アプリの中から新しい版に更新できます（メニューバーのアイコン →「アップデートを確認…」。自動でも確かめます）。更新のときは、手順 2 は要りません。

本物の Pinshelf は、この Releases からだけ配っています。ほかの場所で配られているものは、作者が作ったものではありません。

macOS 26 以降が必要です。ほかの権限（アクセシビリティなど）は求めません。

ソースからビルドする方法は [README](https://github.com/nexy-apps/pinshelf#readme) を見てください。

---

**English:** Requires macOS 26 or later. Download the dmg (or zip), drag `Pinshelf.app` to Applications, open it once and choose "Done" (not "Move to Trash") on the "“Pinshelf.app” Not Opened" dialog, then allow it in System Settings → Privacy & Security ("Open Anyway"), or run `xattr -dr com.apple.quarantine /Applications/Pinshelf.app`. The app is signed with the author's own certificate (not a Developer ID) and is not notarized. Once installed, it updates itself from the menu bar ("アップデートを確認…"). Official builds are distributed only from these GitHub Releases.
