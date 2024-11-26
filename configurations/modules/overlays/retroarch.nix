self: super: {
  retroarch = super.retroarch.override {
    core = with libretro; [
      genesis-plus-gx
      snes9x
      beetle-psx-hw
      dolphin
    ];
  };
}
