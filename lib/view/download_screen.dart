import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/deck_entity.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/deck_repository.dart';
import 'package:leitner_cards/service/drive_service.dart';
import 'package:leitner_cards/service/drive_sync_service.dart';

/// User's selection from the sync options dialog.
class _SyncOptions {
  final bool cards;
  final bool progress;
  final bool deckInfo;
  const _SyncOptions(this.cards, this.progress, this.deckInfo);
}

/// Represents a deck item in the sync list — either local or cloud-only.
class _SyncItem {
  final DeckEntity? deck; // null for cloud-only
  final String driveFolderName;
  final bool isCloudOnly;

  _SyncItem.local(this.deck)
      : driveFolderName = Get.find<DriveSyncService>().driveFolderName(deck!),
        isCloudOnly = false;

  _SyncItem.cloud(this.driveFolderName)
      : deck = null,
        isCloudOnly = true;

  String get id => deck?.id ?? 'cloud:$driveFolderName';
  String get displayName => deck?.name ?? driveFolderName;
}

/// Sync screen — select decks then upload/download/reset via Google Drive.
class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final DriveSyncService _syncService = Get.find<DriveSyncService>();
  final DriveService _driveService = Get.find<DriveService>();
  final CardRepository _cardRepo = Get.find<CardRepository>();
  final DeckRepository _deckRepo = Get.find<DeckRepository>();

  List<_SyncItem> _items = [];
  final Set<String> _selectedIds = {};
  bool _loading = false;
  bool _loadingFolders = false;
  String? _activeAction;

  @override
  void initState() {
    super.initState();
    _refreshItems(selectAll: true);
  }

  void _refreshItems({bool selectAll = false}) {
    final decks = _deckRepo.findAll();
    _items = decks.map((d) => _SyncItem.local(d)).toList();
    // Remove stale selections for items that no longer exist
    final validIds = _items.map((i) => i.id).toSet();
    _selectedIds.retainAll(validIds);
    if (selectAll) _selectedIds.addAll(validIds);
  }

  /// Refresh only the items that were acted on (by id).
  void _refreshSelectedItems(List<_SyncItem> acted) {
    final allDecks = _deckRepo.findAll();
    setState(() {
      for (final item in acted) {
        final idx = _items.indexWhere((i) => i.id == item.id);
        if (idx == -1) continue;
        if (item.isCloudOnly) {
          // Cloud-only item may now exist locally after download
          final folderName = item.driveFolderName;
          final localDeck = allDecks
              .where((d) => _syncService.driveFolderName(d) == folderName)
              .firstOrNull;
          if (localDeck != null) {
            // Replace cloud-only with local item, keep selected
            _selectedIds.remove(item.id);
            _items[idx] = _SyncItem.local(localDeck);
            _selectedIds.add(_items[idx].id);
          }
        } else {
          // Re-fetch the local deck (card count may have changed)
          final fresh =
              allDecks.where((d) => d.id == item.deck!.id).firstOrNull;
          if (fresh != null) {
            _items[idx] = _SyncItem.local(fresh);
          }
        }
      }
    });
  }

  /// Fetch Drive folders and add cloud-only items.
  Future<void> _loadCloudFolders() async {
    if (!await _ensureSignedIn()) return;
    setState(() => _loadingFolders = true);
    try {
      final folders = await _driveService.listDeckFolders();
      final localFolderNames = _items
          .where((i) => !i.isCloudOnly)
          .map((i) => i.driveFolderName)
          .toSet();
      final cloudOnly = folders
          .where((f) => !localFolderNames.contains(f))
          .map((f) => _SyncItem.cloud(f))
          .toList();
      if (mounted) {
        setState(() {
          // Remove old cloud-only items, add fresh ones
          _items.removeWhere((i) => i.isCloudOnly);
          _items.addAll(cloudOnly);
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to list Drive folders: $e');
    } finally {
      if (mounted) setState(() => _loadingFolders = false);
    }
  }

  int _cardCount(_SyncItem item) {
    if (item.deck == null) return 0;
    final code = _syncService.cardCode(item.deck!);
    return _cardRepo.findAllByCode(code).length;
  }

  List<_SyncItem> get _selectedItems =>
      _items.where((i) => _selectedIds.contains(i.id)).toList();

  bool get _allSelected =>
      _items.isNotEmpty && _selectedIds.length == _items.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_items.map((i) => i.id));
      }
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<bool> _ensureSignedIn() async {
    if (_driveService.isAuthorized) return true;
    return await _driveService.authorize();
  }

  // ────────────────────── SYNC OPTIONS DIALOG ──────────────────────

  /// Shows a modal asking which data to sync. Cards is checked by default.
  /// Returns null if the user cancels.
  Future<_SyncOptions?> _showSyncOptionsDialog(String action) async {
    bool cards = true;
    bool progress = false;
    bool deckInfo = false;

    return showDialog<_SyncOptions>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(action),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                dense: true,
                title: const Text('Cards'),
                subtitle: const Text('Flashcard content'),
                value: cards,
                onChanged: (v) => setDialogState(() => cards = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Progress'),
                subtitle: const Text('Study levels & order'),
                value: progress,
                onChanged: (v) => setDialogState(() => progress = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Deck info'),
                subtitle: const Text('Name, icon, color, sort order'),
                value: deckInfo,
                onChanged: (v) => setDialogState(() => deckInfo = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (cards || progress || deckInfo)
                  ? () => Navigator.pop(
                      ctx, _SyncOptions(cards, progress, deckInfo))
                  : null,
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────── BATCH ACTIONS ──────────────────────

  Future<void> _uploadSelected() async {
    if (!await _ensureSignedIn()) return;
    final items = _selectedItems.where((i) => !i.isCloudOnly).toList();
    if (items.isEmpty) {
      _showSnack('No local decks selected to upload');
      return;
    }
    final opts = await _showSyncOptionsDialog('Upload');
    if (opts == null) return;
    setState(() {
      _loading = true;
      _activeAction = 'upload';
    });
    try {
      final results = <DriveSyncResult>[];
      for (final item in items) {
        results.add(await _syncService.uploadDeck(
          item.deck!,
          syncCards: opts.cards,
          syncProgress: opts.progress,
          syncDeckMeta: opts.deckInfo,
        ));
      }
      if (mounted) {
        _refreshSelectedItems(items);
        _showResultsDialog('Upload', results);
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _activeAction = null;
        });
    }
  }

  Future<void> _downloadSelected() async {
    if (!await _ensureSignedIn()) return;
    final items = _selectedItems;
    if (items.isEmpty) return;
    final opts = await _showSyncOptionsDialog('Download');
    if (opts == null) return;
    setState(() {
      _loading = true;
      _activeAction = 'download';
    });
    try {
      final results = <DriveSyncResult>[];
      for (final item in items) {
        if (item.isCloudOnly) {
          results.add(await _syncService.downloadCloudFolder(
            item.driveFolderName,
            syncCards: opts.cards,
            syncProgress: opts.progress,
            syncDeckMeta: opts.deckInfo,
          ));
        } else {
          results.add(await _syncService.downloadDeck(
            item.deck!,
            syncCards: opts.cards,
            syncProgress: opts.progress,
            syncDeckMeta: opts.deckInfo,
          ));
        }
      }
      if (mounted) {
        _refreshSelectedItems(items);
        _showResultsDialog('Download', results);
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _activeAction = null;
        });
    }
  }

  Future<void> _resetSelected() async {
    final items = _selectedItems.where((i) => !i.isCloudOnly).toList();
    if (items.isEmpty) {
      _showSnack('No local decks selected to reset');
      return;
    }
    final names = items.map((i) => i.displayName).join(', ');
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Progress'),
        content: Text(
            'Reset all card levels to 0 for:\n$names\n\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _loading = true;
      _activeAction = 'reset';
    });
    try {
      int total = 0;
      for (final item in items) {
        total += await _syncService.resetProgress(item.deck!);
      }
      if (mounted) {
        _refreshSelectedItems(items);
        _showSnack('🔄 $total cards reset to level 0');
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _activeAction = null;
        });
    }
  }

  // ──────────────────────── UI HELPERS ──────────────────────────

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showResultsDialog(String action, List<DriveSyncResult> results) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Text('$action Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.map((r) {
            final String status;
            if (r.hasError) {
              status = '❌ ${r.error}';
            } else if (r.updated == 0 && r.inserted == 0) {
              status = '✅ Up to date (${r.uploaded} cards)';
            } else {
              final parts = <String>[];
              if (r.uploaded > 0) parts.add('${r.uploaded} uploaded');
              if (r.updated > 0) parts.add('${r.updated} updated');
              if (r.inserted > 0) parts.add('+${r.inserted} new');
              if (r.progressSynced > 0)
                parts.add('${r.progressSynced} progress');
              status = parts.join(', ');
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.deckName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(status,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  // ──────────────────────── BUILD ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading || _loadingFolders ? null : _loadCloudFolders,
            icon: _loadingFolders
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_outlined),
            tooltip: 'Check Drive for more decks',
          ),
          TextButton.icon(
            onPressed: _items.isEmpty ? null : _toggleAll,
            icon: Icon(
              _allSelected ? Icons.deselect : Icons.select_all,
              size: 20,
            ),
            label: Text(_allSelected ? 'None' : 'All'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_sync_outlined,
                      color: Colors.blue.shade600, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Google Drive Sync',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        'Select decks, then download, upload, or reset.',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Selection count
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Text(
                    '${_selectedIds.length} of ${_items.length} selected',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          // Deck list
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                        'No decks yet. Create a deck or tap ☁ to check Drive.',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 14)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) =>
                        _buildDeckTile(_items[index]),
                  ),
          ),
          // Loading indicator
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(
                    '${_activeAction ?? 'Syncing'}…',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          // Action buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  _actionButton(
                    icon: Icons.cloud_download_outlined,
                    label: 'Download',
                    color: Colors.blue.shade600,
                    onPressed:
                        _loading || !hasSelection ? null : _downloadSelected,
                  ),
                  const SizedBox(width: 10),
                  _actionButton(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Upload',
                    color: Colors.green.shade600,
                    onPressed:
                        _loading || !hasSelection ? null : _uploadSelected,
                  ),
                  const SizedBox(width: 10),
                  _actionButton(
                    icon: Icons.restart_alt_outlined,
                    label: 'Reset',
                    color: Colors.red.shade600,
                    onPressed:
                        _loading || !hasSelection ? null : _resetSelected,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckTile(_SyncItem item) {
    final cs = Theme.of(context).colorScheme;
    final deck = item.deck;
    final accentColor =
        deck != null ? Color(deck.colorValue) : Colors.grey.shade400;
    final count = _cardCount(item);
    final selected = _selectedIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? (item.isCloudOnly
                ? Colors.orange.shade50
                : cs.primaryContainer.withAlpha(60))
            : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: selected
            ? Border.all(
                color: item.isCloudOnly
                    ? Colors.orange.withAlpha(120)
                    : cs.primary.withAlpha(120),
                width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _loading ? null : () => _toggle(item.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: _loading ? null : (_) => _toggle(item.id),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(item.isCloudOnly ? 30 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isCloudOnly
                      ? Icons.cloud_download_outlined
                      // ignore: non_const_argument_for_const_parameter
                      : IconData(deck!.iconCodePoint,
                          fontFamily: 'MaterialIcons'),
                  color:
                      item.isCloudOnly ? Colors.orange.shade700 : accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        if (item.isCloudOnly) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Cloud',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isCloudOnly
                          ? 'On Drive · tap Download to import'
                          : '$count card${count == 1 ? '' : 's'} · '
                              '${_syncService.deckCode(deck!)}',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withAlpha(60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}
