/// Cities and major towns across Somalia for location pickers.
class SomaliaCities {
  SomaliaCities._();

  static const List<String> all = [
    'Abudwak',
    'Adado',
    'Afgooye',
    'Afmadow',
    'Baidoa',
    'Balcad',
    'Bandarbeyla',
    'Baraawe',
    'Bardera',
    'Beled Hawo',
    'Beledweyne',
    'Berbera',
    'Boroma',
    'Bosaso',
    'Buale',
    'Burao',
    'Burtinle',
    'Buuhoodle',
    'Buuloburde',
    'Cadale',
    'Caluula',
    'Caynabo',
    'Ceel Buur',
    'Ceel Waaq',
    'Ceerigaabo',
    'Dhobley',
    'Dhusamareb',
    'Dolo',
    'El Afweyn',
    'Eyl',
    'Gabiley',
    'Galdogob',
    'Galkayo',
    'Garbahaarey',
    'Garowe',
    'Goldogob',
    'Hargeisa',
    'Hobyo',
    'Iskushuban',
    'Jalalaqsi',
    'Jamaame',
    'Jariban',
    'Jilib',
    'Jowhar',
    'Kismayo',
    'Kurtunwaarey',
    'Laascaanood',
    'Las Qoray',
    'Luuq',
    'Mahaday',
    'Marka',
    'Mogadishu',
    'Odweine',
    'Qandala',
    'Qardho',
    'Qoryooley',
    'Runirgod',
    'Saakow',
    'Sablaale',
    'Sheikh',
    'Taleh',
    'Tayeeglow',
    'Wanlaweyn',
    'Warsheikh',
    'Wajid',
    'Xarardheere',
    'Xudur',
    'Xudun',
  ];

  /// Match a saved/free-text value to a known city (case-insensitive).
  static String? match(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    for (final city in all) {
      if (city.toLowerCase() == raw.toLowerCase()) return city;
    }
    return null;
  }

  static bool contains(String? value) => match(value) != null;
}
