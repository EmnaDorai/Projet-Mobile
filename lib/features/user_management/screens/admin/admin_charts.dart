import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../widgets/common_widgets.dart';

/// Camembert : répartition des utilisateurs par rôle.
class RolePieChart extends StatelessWidget {
  final Map<UserRole, int> counts;
  const RolePieChart({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox(height: 40, child: Text('Aucune donnée'));
    return Row(children: [
      SizedBox(
        width: 150,
        height: 150,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: [
            for (final e in counts.entries)
              if (e.value > 0)
                PieChartSectionData(
                  value: e.value.toDouble(),
                  color: roleColor(e.key),
                  radius: 38,
                  title: '${(e.value * 100 / total).round()}%',
                  titleStyle: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
          ],
        )),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in counts.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: roleColor(e.key), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(e.key.label)),
                Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

/// Histogramme : inscriptions par mois (6 derniers mois).
class SignupsBarChart extends StatelessWidget {
  final Map<String, int> byMonth; // « 2026-10 » → n
  const SignupsBarChart({super.key, required this.byMonth});

  static const _mois = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
                        'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];
    String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
    final values = [for (final m in months) byMonth[key(m)] ?? 0];
    final maxV = values.fold(0, (a, b) => a > b ? a : b);
    final top = maxV < 4 ? 4.0 : (maxV * 1.25).ceilToDouble();

    return SizedBox(
      height: 190,
      child: BarChart(BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (top / 4).ceilToDouble(),
          getDrawingHorizontalLine: (_) =>
              // ignore: prefer_const_constructors
              FlLine(color: AppColors.line, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (top / 4).ceilToDouble(),
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_mois[months[i].month - 1],
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i].toDouble(),
                width: 20,
                color: i == values.length - 1 ? AppColors.harissa : AppColors.oliveSoft,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ]),
        ],
      )),
    );
  }
}
