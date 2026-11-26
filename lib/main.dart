import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const ClimaApp());

// 
// App
// 
class ClimaApp extends StatelessWidget {
  const ClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clima',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const WeatherPage(),
    );
  }
}

// 
// Models
// 
class Place {
  final String name;
  final double latitude;
  final double longitude;
  const Place(this.name, this.latitude, this.longitude);
}

class Day {
  final DateTime date;
  final int code;
  final double high;
  final double low;
  const Day(this.date, this.code, this.high, this.low);
}

class Weather {
  final String place;
  final double temp;
  final double feels;
  final double wind;
  final int humidity;
  final int code;
  final bool isDay;
  final List<Day> days;
  const Weather({
    required this.place,
    required this.temp,
    required this.feels,
    required this.wind,
    required this.humidity,
    required this.code,
    required this.isDay,
    required this.days,
  });
}

// 
// API (Open-Meteo, no key needed)
// 
class WeatherService {
  static Future<Place> findCity(String name) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {'name': name, 'count': '1'},
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Could not reach the server.');

    final results = jsonDecode(res.body)['results'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('No city found for "$name". Check the spelling.');
    }
    final r = results.first;
    return Place(
      '${r['name']}, ${r['country_code']}',
      (r['latitude'] as num).toDouble(),
      (r['longitude'] as num).toDouble(),
    );
  }

  static Future<Weather> fetch(Place place) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${place.latitude}',
      'longitude': '${place.longitude}',
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'timezone': 'auto',
      'forecast_days': '5',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Could not load the weather.');

    final data = jsonDecode(res.body);
    final c = data['current'];
    final d = data['daily'];

    final days = List.generate(
      (d['time'] as List).length,
      (i) => Day(
        DateTime.parse(d['time'][i]),
        d['weather_code'][i] as int,
        (d['temperature_2m_max'][i] as num).toDouble(),
        (d['temperature_2m_min'][i] as num).toDouble(),
      ),
    );

    return Weather(
      place: place.name,
      temp: (c['temperature_2m'] as num).toDouble(),
      feels: (c['apparent_temperature'] as num).toDouble(),
      wind: (c['wind_speed_10m'] as num).toDouble(),
      humidity: (c['relative_humidity_2m'] as num).round(),
      code: c['weather_code'] as int,
      isDay: c['is_day'] == 1,
      days: days,
    );
  }
}

// 
// Helpers
// 
String describe(int code) => switch (code) {
      0 => 'Clear sky',
      1 => 'Mostly clear',
      2 => 'Partly cloudy',
      3 => 'Overcast',
      45 || 48 => 'Fog',
      51 || 53 || 55 => 'Drizzle',
      61 || 63 || 65 => 'Rain',
      71 || 73 || 75 => 'Snow',
      80 || 81 || 82 => 'Rain showers',
      95 || 96 || 99 => 'Thunderstorm',
      _ => 'Unknown',
    };

List<Color> skyColors(int code, bool isDay) {
  if (!isDay) return const [Color(0xFF0F1B33), Color(0xFF35456B)];
  if ((code >= 51 && code <= 65) || (code >= 80 && code <= 99)) {
    return const [Color(0xFF2D3B4F), Color(0xFF6F8197)];
  }
  if (code >= 71 && code <= 75) {
    return const [Color(0xFF6C7F96), Color(0xFFD8E3EE)];
  }
  if (code == 2 || code == 3 || code == 45 || code == 48) {
    return const [Color(0xFF55657A), Color(0xFFAAB6C4)];
  }
  return const [Color(0xFF2B5D8A), Color(0xFF8FC1E3)];
}

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

const _panel = Color(0x24FFFFFF);
const _soft = Color(0xBFFFFFFF);

// 
// Screen
// 
class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final _controller = TextEditingController();
  Weather? _weather;
  String _message = '';
  bool _fahrenheit = false;

  @override
  void initState() {
    super.initState();
    _search('Lagos'); // default city
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String name) async {
    name = name.trim();
    if (name.isEmpty) {
      setState(() => _message = 'Type a city name to search.');
      return;
    }
    setState(() => _message = 'Loading…');
    try {
      final place = await WeatherService.findCity(name);
      final weather = await WeatherService.fetch(place);
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _message = '';
      });
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _t(double c) => '${(_fahrenheit ? c * 9 / 5 + 32 : c).round()}°';

  @override
  Widget build(BuildContext context) {
    final w = _weather;
    final colors = w == null
        ? const [Color(0xFF2B5D8A), Color(0xFF8FC1E3)]
        : skyColors(w.code, w.isDay);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _searchBar(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_message, style: const TextStyle(color: _soft)),
                  ),
                  if (w != null) ..._content(w),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: _search,
      decoration: InputDecoration(
        hintText: 'Search for a city',
        hintStyle: const TextStyle(color: _soft),
        filled: true,
        fillColor: _panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => _search(_controller.text),
        ),
      ),
    );
  }

  List<Widget> _content(Weather w) {
    return [
      const SizedBox(height: 12),
      Text(w.place,
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
      Text(
        _t(w.temp),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 104, fontWeight: FontWeight.w200),
      ),
      Text(describe(w.code),
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 24),
      Row(
        children: [
          _detail('Feels like', _t(w.feels)),
          const SizedBox(width: 8),
          _detail('Humidity', '${w.humidity}%'),
          const SizedBox(width: 8),
          _detail('Wind', '${w.wind.round()} km/h'),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            for (var i = 0; i < w.days.length; i++) _dayRow(w.days[i], i == 0),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _fahrenheit = !_fahrenheit),
          child: Text(_fahrenheit ? 'Switch to °C' : 'Switch to °F'),
        ),
      ),
    ];
  }

  Widget _detail(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: _soft, fontSize: 13)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 17)),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(Day d, bool today) {
    final name = today ? 'Today' : _weekdays[d.date.weekday - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text('$name · ${describe(d.code)}')),
          Text(_t(d.high)),
          const SizedBox(width: 16),
          Text(_t(d.low), style: const TextStyle(color: _soft)),
        ],
      ),
    );
  }
}