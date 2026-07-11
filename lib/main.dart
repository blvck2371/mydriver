import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/map_screen.dart';
import 'state/transit_state.dart';

void main() {
  runApp(const TransitProcheApp());
}

class TransitProcheApp extends StatelessWidget {
  const TransitProcheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransitState()..init(),
      child: MaterialApp(
        title: 'Transit Proche',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00C853),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00C853),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const MapScreen(),
      ),
    );
  }
}
