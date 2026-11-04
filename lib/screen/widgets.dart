import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// 'yyyy-MM-dd' -> 'dd/MM/yyyy' (empty stays empty).
String fmtDate(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

/// 'yyyy-MM-dd' -> 'dd/MM'.
String fmtDay(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}' : iso;
}

/// Server timestamps are UTC without a zone suffix; show them in local time.
String fmtDateTime(String iso) {
  final d = DateTime.tryParse('${iso}Z')?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} - ${two(d.hour)}:${two(d.minute)}';
}

String fmtScore(double? v, {int digits = 1}) =>
    v == null ? '-' : v.toStringAsFixed(digits);

String messageOf(Object e) => e is AuthException ? e.message : 'Something went wrong. Please try again.';

String roleName(String role) => switch (role) {
      'PH' => 'Phụ huynh',
      'HS' => 'Học sinh',
      'GV' => 'Giáo viên',
      'Manager' => 'Quản lý',
      _ => role,
    };

/// Centers content in a column of at most [Space.maxContentWidth] so the app
/// stays readable in a wide browser window.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Space.maxContentWidth),
          child: child,
        ),
      );
}

/// Pull-to-refresh around a scrollable; [reload] swaps the screen's future.
class RefreshList extends StatelessWidget {
  const RefreshList({
    super.key,
    required this.onRefresh,
    required this.children,
    this.padding = const EdgeInsets.all(Space.gutter),
  });
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        color: AppColors.brandStrong,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: children,
        ),
      );
}

/// Shows a skeleton, an error (with retry) or the data for a future.
class FutureView<T> extends StatelessWidget {
  const FutureView(
      {super.key,
      required this.future,
      required this.builder,
      required this.onRetry});

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const PageBody(child: SkeletonList());
        }
        if (snap.hasError) {
          return PageBody(
              child: ErrorState(messageOf(snap.error!), onRetry: onRetry));
        }
        return PageBody(child: builder(context, snap.data as T));
      },
    );
  }
}

/// Placeholder rows with a slow opacity pulse. No pulse when the OS asks for
/// reduced motion.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 5});
  final int count;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(Radii.control / 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải',
      liveRegion: true,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) =>
                Opacity(opacity: 1 - 0.5 * _c.value, child: child),
            child: ListView(
              key: const Key('skeleton'),
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Space.gutter),
              children: [
                for (var i = 0; i < widget.count; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: Space.md),
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(150, 14),
                        const SizedBox(height: Space.sm),
                        _bar(double.infinity, 12),
                        const SizedBox(height: Space.xs + 2),
                        _bar(100, 12),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon, one sentence, and optionally the action that adds the first item.
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.message,
      this.actionLabel,
      this.onAction});
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.xl, vertical: Space.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
                child: Icon(icon, size: 48, color: AppColors.control)),
            const SizedBox(height: Space.md),
            Text(message,
                textAlign: TextAlign.center, style: context.text.bodyLarge),
            if (actionLabel != null) ...[
              const SizedBox(height: Space.lg),
              ElevatedButton.icon(
                key: const Key('emptyAction'),
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(
                  child: Icon(Icons.error_outline,
                      size: 40, color: AppColors.danger)),
              const SizedBox(height: Space.md),
              Text(message,
                  key: const Key('loadError'),
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge
                      ?.copyWith(color: AppColors.danger)),
              const SizedBox(height: Space.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
}

/// Inline form error: icon + text, announced as a live region.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key, this.textKey});
  final String message;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                  child: Icon(Icons.error_outline,
                      size: 20, color: AppColors.danger)),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(message,
                    key: textKey,
                    style: context.text.bodyMedium
                        ?.copyWith(color: AppColors.danger)),
              ),
            ],
          ),
        ),
      );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.card);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: AppColors.line)),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: onTap == null ? 0 : 56),
            child: Padding(
                padding: padding ?? const EdgeInsets.all(Space.lg),
                child: child),
          ),
        ),
      ),
    );
  }
}

/// Card with a heading, used for free-text sections on detail screens.
class SectionCard extends StatelessWidget {
  const SectionCard(this.title, {super.key, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                  header: true,
                  child: Text(title, style: context.text.titleSmall)),
              const SizedBox(height: Space.sm),
              child,
            ],
          ),
        ),
      );
}

enum StatusKind { pending, approved, rejected, action }

/// Pill with icon + label so status never relies on colour alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.kind, this.label, {super.key});

  final StatusKind kind;
  final String label;

  /// Request status from the API ('pending' / 'approved' / 'rejected').
  factory StatusBadge.request(String status, {Key? key}) => switch (status) {
        'pending' => StatusBadge(StatusKind.pending, 'Chờ duyệt', key: key),
        'approved' => StatusBadge(StatusKind.approved, 'Đã duyệt', key: key),
        _ => StatusBadge(StatusKind.rejected, 'Từ chối', key: key),
      };

  (IconData, Color, Color) get _style => switch (kind) {
        StatusKind.pending => (
            Icons.hourglass_empty,
            AppColors.warning,
            AppColors.warningSoft
          ),
        StatusKind.approved => (
            Icons.check_circle_outline,
            AppColors.success,
            AppColors.successSoft
          ),
        StatusKind.rejected => (
            Icons.highlight_off,
            AppColors.danger,
            AppColors.dangerSoft
          ),
        StatusKind.action => (
            Icons.add_circle_outline,
            AppColors.brandStrong,
            AppColors.brandSoft
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = _style;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 4),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(label,
                  style: context.text.labelMedium?.copyWith(color: fg)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Label on the left, value on the right.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm + 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.bodyMedium
                  ?.copyWith(color: AppColors.muted)),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Text(value.isEmpty ? '-' : value,
                    textAlign: TextAlign.right,
                    style: context.text.labelLarge),
              ),
            ],
          ),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label,
      {super.key,
      required this.onPressed,
      this.color,
      this.loading = false,
      this.outlined = false});
  final String label;
  final VoidCallback? onPressed;

  /// Overrides the brand fill, e.g. danger / success for decisions.
  final Color? color;
  final bool loading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: outlined ? AppColors.brandStrong : Colors.white))
        : Text(label, textAlign: TextAlign.center);
    final action = loading ? null : onPressed;
    return SizedBox(
      height: Space.minTap,
      child: outlined
          ? OutlinedButton(onPressed: action, child: child)
          : ElevatedButton(
              onPressed: action,
              style: color == null
                  ? null
                  : ElevatedButton.styleFrom(backgroundColor: color),
              child: child),
    );
  }
}

/// Small header strip like "Môn học | Giữa kỳ | Cuối kỳ | TB".
class TableHeader extends StatelessWidget {
  const TableHeader(this.cells, {super.key, required this.flex});
  final List<String> cells;
  final List<int> flex;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.md, vertical: Space.sm + 2),
        decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(Radii.control)),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(cells[i],
                  textAlign: i == 0 ? TextAlign.start : TextAlign.center,
                  style: context.text.labelMedium
                      ?.copyWith(color: AppColors.brandStrong)),
            ),
        ]),
      );
}

enum ScoreLevel { excellent, good, fair, weak }

/// >= 8 giỏi, >= 6.5 khá, >= 5 trung bình, otherwise yếu; null has no level.
ScoreLevel? scoreLevel(double? v) {
  if (v == null) return null;
  if (v >= 8) return ScoreLevel.excellent;
  if (v >= 6.5) return ScoreLevel.good;
  if (v >= 5) return ScoreLevel.fair;
  return ScoreLevel.weak;
}

String scoreLevelName(ScoreLevel l) => switch (l) {
      ScoreLevel.excellent => 'Giỏi',
      ScoreLevel.good => 'Khá',
      ScoreLevel.fair => 'Trung bình',
      ScoreLevel.weak => 'Yếu',
    };

(Color fg, Color bg) scoreColors(ScoreLevel? l) => switch (l) {
      ScoreLevel.excellent => (AppColors.success, AppColors.successSoft),
      ScoreLevel.good => (AppColors.info, AppColors.infoSoft),
      ScoreLevel.fair => (AppColors.warning, AppColors.warningSoft),
      ScoreLevel.weak => (AppColors.danger, AppColors.dangerSoft),
      null => (AppColors.muted, Colors.transparent),
    };

/// A score in a tinted pill; the level name is in the semantics label and in
/// the legend, so colour is never the only signal.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge(this.score, {super.key, this.digits = 1});
  final double? score;
  final int digits;

  @override
  Widget build(BuildContext context) {
    final level = scoreLevel(score);
    final (fg, bg) = scoreColors(level);
    return Semantics(
      label: level == null
          ? 'Chưa có điểm'
          : '${fmtScore(score, digits: digits)}, ${scoreLevelName(level)}',
      child: ExcludeSemantics(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(
                horizontal: Space.sm, vertical: Space.xs),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(Radii.control)),
            child: Text(fmtScore(score, digits: digits),
                textAlign: TextAlign.center,
                style: context.text.labelLarge?.copyWith(
                    color: fg, fontFeatures: tabularFigures)),
          ),
        ),
      ),
    );
  }
}

/// Explains the score colours in words.
class ScoreLegend extends StatelessWidget {
  const ScoreLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.md,
        runSpacing: Space.xs,
        children: [
          for (final (l, range) in const [
            (ScoreLevel.excellent, '8 trở lên'),
            (ScoreLevel.good, '6,5 - 7,9'),
            (ScoreLevel.fair, '5 - 6,4'),
            (ScoreLevel.weak, 'dưới 5'),
          ])
            Row(mainAxisSize: MainAxisSize.min, children: [
              ExcludeSemantics(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: scoreColors(l).$1, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: Space.xs + 2),
              Text('${scoreLevelName(l)} ($range)',
                  style: context.text.bodySmall),
            ]),
        ],
      );
}
