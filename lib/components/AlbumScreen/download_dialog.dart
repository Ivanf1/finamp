import 'dart:async';

import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/finamp_user_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../global_snackbar.dart';

class DownloadDialog extends StatefulWidget {
  const DownloadDialog._build({
    super.key,
    required this.item,
    required this.viewId,
    required this.needsDirectory,
    required this.needsTranscode,
    required this.children,
  });

  final DownloadStub item;
  final String viewId;
  final bool needsDirectory;
  final bool needsTranscode;
  final List<BaseItemDto>? children;

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();

  /// Shows a download dialog box to the user.  A download location dropdown will be shown
  /// if there is more than one location.  A transcode setting dropdown will be shown
  /// if transcode downloads is set to ask.  If neither is needed, the
  /// download is initiated immediately with no dialog.
  static Future<void> show(
      BuildContext context, DownloadStub item, String? viewId) async {
    if (viewId == null) {
      final finampUserHelper = GetIt.instance<FinampUserHelper>();
      viewId = finampUserHelper.currentUser!.currentViewId;
    }
    bool needTranscode =
        FinampSettingsHelper.finampSettings.shouldTranscodeDownloads ==
            TranscodeDownloadsSetting.ask;
    bool needDownload = FinampSettingsHelper
            .finampSettings.downloadLocationsMap.values
            .where((element) =>
                element.baseDirectory != DownloadLocationType.internalDocuments)
            .length !=
        1;
    if (!needTranscode && !needDownload) {
      final downloadsService = GetIt.instance<DownloadsService>();
      var profile = FinampSettingsHelper
                  .finampSettings.shouldTranscodeDownloads ==
              TranscodeDownloadsSetting.always
          ? FinampSettingsHelper.finampSettings.downloadTranscodingProfile
          : DownloadProfile(transcodeCodec: FinampTranscodingCodec.original);
      profile.downloadLocationId =
          FinampSettingsHelper.finampSettings.internalSongDir.id;
      GlobalSnackbar.message((scaffold) =>
          AppLocalizations.of(scaffold)!.confirmDownloadStarted, isConfirmation: true);
      unawaited(downloadsService
          .addDownload(stub: item, viewId: viewId!, transcodeProfile: profile)
          // TODO only show the enqueued confirmation if the enqueuing took longer than ~10 seconds
          .then((value) => GlobalSnackbar.message(
              (scaffold) => AppLocalizations.of(scaffold)!.downloadsQueued)));
    } else {
      JellyfinApiHelper jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
      List<BaseItemDto>? children;
      if (item.baseItemType == BaseItemDtoType.album ||
          item.baseItemType == BaseItemDtoType.playlist) {
        children = await jellyfinApiHelper.getItems(
            parentItem: item.baseItem!,
            includeItemTypes: "Audio",
            fields: "${jellyfinApiHelper.defaultFields},MediaSources");
      }
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => DownloadDialog._build(
            item: item,
            viewId: viewId!,
            needsDirectory: needDownload,
            needsTranscode: needTranscode,
            children: children),
      );
    }
  }
}

class _DownloadDialogState extends State<DownloadDialog> {
  DownloadLocation? selectedDownloadLocation;
  bool? transcode;

  @override
  Widget build(BuildContext context) {
    String originalDescription = "null";
    String transcodeDescription = "null";
    var transcodeProfile =
        FinampSettingsHelper.finampSettings.downloadTranscodingProfile;
    var originalProfile =
        DownloadProfile(transcodeCodec: FinampTranscodingCodec.original);

    if (widget.children != null) {
      final originalFileSize = widget.children!
          .map((e) => e.mediaSources?.first.size ?? 0)
          .fold(0, (a, b) => a + b);

      final transcodedFileSize = widget.children!
          .map((e) => e.mediaSources?.first.transcodedSize(FinampSettingsHelper
              .finampSettings.downloadTranscodingProfile.bitrateChannels))
          .fold(0, (a, b) => a + (b ?? 0));

      final originalFileSizeFormatted = FileSize.getSize(
        originalFileSize,
        precision: PrecisionValue.None,
      );

      final formats = widget.children!
          .map((e) => e.mediaSources?.first.mediaStreams.first.codec)
          .toSet();

      transcodeDescription = FileSize.getSize(
        transcodedFileSize,
        precision: PrecisionValue.None,
      );

      originalDescription =
          "$originalFileSizeFormatted ${formats.length == 1 ? formats.first!.toUpperCase() : "null"}";
    }

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.addDownloads),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.needsDirectory)
            DropdownButton<DownloadLocation>(
                hint: Text(AppLocalizations.of(context)!.location),
                isExpanded: true,
                onChanged: (value) => setState(() {
                      selectedDownloadLocation = value;
                    }),
                value: selectedDownloadLocation,
                items: FinampSettingsHelper
                    .finampSettings.downloadLocationsMap.values
                    .where((element) =>
                        element.baseDirectory !=
                        DownloadLocationType.internalDocuments)
                    .map((e) => DropdownMenuItem<DownloadLocation>(
                          value: e,
                          child: Text(e.name),
                        ))
                    .toList()),
          if (widget.needsTranscode)
            DropdownButton<bool>(
                hint: Text(AppLocalizations.of(context)!.transcodeHint),
                isExpanded: true,
                onChanged: (value) => setState(() {
                      transcode = value;
                    }),
                value: transcode,
                items: [
                  DropdownMenuItem<bool>(
                    value: true,
                    child: Text(AppLocalizations.of(context)!.doTranscode(
                        transcodeProfile.bitrateKbps,
                        transcodeProfile.codec.name.toUpperCase(),
                        transcodeDescription)),
                  ),
                  DropdownMenuItem<bool>(
                    value: false,
                    child: Text(AppLocalizations.of(context)!
                        .dontTranscode(originalDescription)),
                  )
                ]),
        ],
      ),
      actions: [
        TextButton(
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: (selectedDownloadLocation == null &&
                      widget.needsDirectory) ||
                  (transcode == null && widget.needsTranscode)
              ? null
              : () async {
                  Navigator.of(context).pop();
                  final downloadsService = GetIt.instance<DownloadsService>();
                  var profile = (widget.needsTranscode
                          ? transcode
                          : FinampSettingsHelper
                                  .finampSettings.shouldTranscodeDownloads ==
                              TranscodeDownloadsSetting.always)!
                      ? transcodeProfile
                      : originalProfile;
                  profile.downloadLocationId = widget.needsDirectory
                      ? selectedDownloadLocation!.id
                      : FinampSettingsHelper.finampSettings.internalSongDir.id;
                  await downloadsService
                      .addDownload(
                          stub: widget.item,
                          viewId: widget.viewId,
                          transcodeProfile: profile)
                      .onError(
                          (error, stackTrace) => GlobalSnackbar.error(error));

                  GlobalSnackbar.message((scaffold) =>
                      AppLocalizations.of(scaffold)!.downloadsQueued);
                },
          child: Text(AppLocalizations.of(context)!.addButtonLabel),
        )
      ],
    );
  }
}
