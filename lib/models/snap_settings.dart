class SnapMapSettings {
  String themeName;
  String layout; // 'radial', 'tree', 'horizontal', 'vertical'
  double textSize;
  double branchThickness;
  bool isCompact;

  SnapMapSettings({
    this.themeName = 'Ocean',
    this.layout = 'radial',
    this.textSize = 14.0,
    this.branchThickness = 2.5,
    this.isCompact = false,
  });

  SnapMapSettings copyWith({
    String? themeName,
    String? layout,
    double? textSize,
    double? branchThickness,
    bool? isCompact,
  }) {
    return SnapMapSettings(
      themeName: themeName ?? this.themeName,
      layout: layout ?? this.layout,
      textSize: textSize ?? this.textSize,
      branchThickness: branchThickness ?? this.branchThickness,
      isCompact: isCompact ?? this.isCompact,
    );
  }
}
