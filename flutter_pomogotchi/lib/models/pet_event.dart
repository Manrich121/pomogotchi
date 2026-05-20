enum PetEvent {
  startFocusSession,
  pauseFocusSession,
  resumeFocusSession,
  completeFocusSession,
  stopFocusSessionEarly,
  startBreak,
  completeBreak,
  stopBreakEarly,
  petPet,
  drinkWater,
  moveOrStretch,
}

extension PetEventX on PetEvent {
  String get wireValue {
    return switch (this) {
      PetEvent.startFocusSession => 'start_focus_session',
      PetEvent.pauseFocusSession => 'pause_focus_session',
      PetEvent.resumeFocusSession => 'resume_focus_session',
      PetEvent.completeFocusSession => 'complete_focus_session',
      PetEvent.stopFocusSessionEarly => 'stop_focus_session_early',
      PetEvent.startBreak => 'start_break',
      PetEvent.completeBreak => 'complete_break',
      PetEvent.stopBreakEarly => 'stop_break_early',
      PetEvent.petPet => 'pet_pet',
      PetEvent.drinkWater => 'drink_water',
      PetEvent.moveOrStretch => 'move_or_stretch',
    };
  }

  String get label {
    return switch (this) {
      PetEvent.startFocusSession => 'Start focus',
      PetEvent.pauseFocusSession => 'Pause focus',
      PetEvent.resumeFocusSession => 'Resume focus',
      PetEvent.completeFocusSession => 'Complete focus',
      PetEvent.stopFocusSessionEarly => 'Stop focus early',
      PetEvent.startBreak => 'Start break',
      PetEvent.completeBreak => 'Complete break',
      PetEvent.stopBreakEarly => 'Stop break early',
      PetEvent.petPet => 'Pet pet',
      PetEvent.drinkWater => 'Drink water',
      PetEvent.moveOrStretch => 'Move or stretch',
    };
  }

  bool get isWellnessEvent {
    return switch (this) {
      PetEvent.petPet || PetEvent.drinkWater || PetEvent.moveOrStretch => true,
      _ => false,
    };
  }

  bool get isSessionLifecycleEvent {
    return switch (this) {
      PetEvent.petPet || PetEvent.drinkWater || PetEvent.moveOrStretch => false,
      _ => true,
    };
  }
}
