import '../models/model_models.dart';

class PowerModeService {
  PowerMode _currentMode = PowerMode.normal;

  PowerMode get currentMode => _currentMode;

  void setMode(PowerMode mode) {
    _currentMode = mode;
  }

  ModelProfile profileFor({
    required PowerMode mode,
    required ModelTier activeTier,
  }) {
    if (mode == PowerMode.doomsday) {
      return ModelProfile.e2bSaver;
    }

    return switch (activeTier) {
      ModelTier.e2b => ModelProfile.e2bBalanced,
      ModelTier.e4b => ModelProfile.e4bExpert,
    };
  }
}
