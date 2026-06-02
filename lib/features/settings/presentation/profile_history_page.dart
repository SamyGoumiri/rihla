import 'package:flutter/material.dart';
import 'package:rihla/core/services/history_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/data/repositories/site_repository.dart';
import 'package:rihla/features/shared/widgets/profile_collection_widgets.dart';
import 'package:rihla/features/sites/presentation/site_detail_page.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class ProfileHistoryPage extends StatefulWidget {
  const ProfileHistoryPage({
    super.key,
    HistoryService? historyService,
    SiteRepository? repository,
  }) : _historyService = historyService,
       _repository = repository;

  final HistoryService? _historyService;
  final SiteRepository? _repository;

  @override
  State<ProfileHistoryPage> createState() => _ProfileHistoryPageState();
}

class _ProfileHistoryPageState extends State<ProfileHistoryPage> {
  late final HistoryService _historyService =
      widget._historyService ?? HistoryService();
  late final SiteRepository _repository =
      widget._repository ?? SiteRepository.instance;

  List<HistoryEntry> _historyEntries = <HistoryEntry>[];
  Map<String, TouristSite> _sitesById = <String, TouristSite>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final List<HistoryEntry> history = await _historyService.getHistory();
    final List<TouristSite> sites = await _repository.getSites();
    final Map<String, TouristSite> sitesById = <String, TouristSite>{
      for (final TouristSite site in sites) site.id: site,
    };

    if (!mounted) return;

    setState(() {
      _historyEntries = history;
      _sitesById = sitesById;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    await _loadHistory();
  }

  Future<void> _confirmClearHistory() async {
    final palette = RihlaPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Effacer l\'historique ?'),
          content: Text(
            'Toutes les fiches consultées seront retirées de cet historique. '
            'Vos favoris et avis ne sont pas affectés.',
            style: AppTypography.body.copyWith(
              color: palette.textSecondary,
              fontSize: 13.6,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: palette.dangerForeground,
                foregroundColor: Colors.white,
              ),
              child: const Text('Effacer'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _historyService.clearAll();
    await _loadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Historique effacé.')));
  }

  void _openSite(TouristSite site) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SiteDetailPage(site: site)));
  }

  String _formatSeenDate(DateTime dateTime) {
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return 'Consulté le $day/$month à $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final List<HistoryEntry> visibleEntries = _historyEntries
        .where((HistoryEntry entry) => _sitesById.containsKey(entry.siteId))
        .toList();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ProfileCollectionPage(
      title: 'Historique des consultations',
      subtitle: 'Les fiches que vous avez ouvertes récemment',
      countText:
          '${visibleEntries.length} consultation${visibleEntries.length > 1 ? 's' : ''} enregistrée${visibleEntries.length > 1 ? 's' : ''}',
      icon: Icons.history_rounded,
      onRefresh: _refresh,
      child: visibleEntries.isEmpty
          ? const ProfileCollectionEmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'Aucune consultation enregistrée',
              message:
                  'Ouvrez des fiches de sites pour alimenter automatiquement cet historique.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _confirmClearHistory,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Effacer l\'historique'),
                    style: TextButton.styleFrom(
                      foregroundColor: RihlaPalette.of(
                        context,
                      ).dangerForeground,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                ...visibleEntries.map((HistoryEntry entry) {
                  final TouristSite site = _sitesById[entry.siteId]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                    child: ProfileDestinationRow(
                      site: site,
                      onTap: () => _openSite(site),
                      badgeText: _formatSeenDate(entry.viewedAt),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
