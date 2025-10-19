part of 'theme_bloc.dart';

abstract class ThemeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ThemeLoadRequested extends ThemeEvent {}

class ThemeModeChanged extends ThemeEvent {
  final ThemeMode themeMode;
  ThemeModeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}



