import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences sharedPreferences;
  static const _key = 'themeMode';

  ThemeBloc(this.sharedPreferences) : super(ThemeInitial()) {
    on<ThemeLoadRequested>(_onLoad);
    on<ThemeModeChanged>(_onChanged);
  }

  Future<void> _onLoad(ThemeLoadRequested event, Emitter<ThemeState> emit) async {
    final saved = sharedPreferences.getString(_key);
    final mode = _stringToMode(saved) ?? ThemeMode.system;
    emit(ThemeLoaded(mode));
  }

  Future<void> _onChanged(ThemeModeChanged event, Emitter<ThemeState> emit) async {
    await sharedPreferences.setString(_key, _modeToString(event.themeMode));
    emit(ThemeLoaded(event.themeMode));
  }

  String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode? _stringToMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
    }
    return null;
  }
}



