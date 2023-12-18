import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../components/DownloadsScreen/downloads_overview.dart';
import '../components/DownloadsScreen/downloaded_albums_list.dart';
import '../components/DownloadsScreen/download_error_screen_button.dart';
import '../components/DownloadsScreen/download_missing_images_button.dart';
import '../components/DownloadsScreen/sync_downloaded_playlists.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  static const routeName = "/downloads";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.downloads),
        actions: const [
          SyncDownloadedPlaylistsButton(),
          DownloadMissingImagesButton(), // TODO replace with somthing actually usefull.
          DownloadErrorScreenButton()
        ],
      ),
      body: Scrollbar(
        child: CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  // We don't have bottom padding here since the divider already provides bottom padding
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: DownloadsOverview(),
                ),
                const Divider(),
              ]),
            ),
            const DownloadedAlbumsList(),
            // CurrentDownloadsList(),
          ],
        ),
      ),
    );
  }
}
