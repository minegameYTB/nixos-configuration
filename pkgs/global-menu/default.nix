{
  lib,
  python3Packages,
  fetchFromGitHub,
  gtk3,
  atk,
  pango,
  gdk-pixbuf,
  cairo,
  wrapGAppsHook3,
}:

python3Packages.buildPythonApplication rec {
  pname = "global-menu";
  version = "1.1.4";

  ### Plain setup.py, no pyproject.toml/setup.cfg — `format = "setuptools"`
  ### picks up setuptoolsBuildHook (pyproject = false would leave the generic
  ### `make` buildPhase, which builds the Debian package instead).
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Unmade760";
    repo = "orbit-global-menu";
    rev = "77ea74cf9828c3b776af7114f1c65c290683dbca";
    hash = "sha256-mcDxliIxSJw4ffHU7SXj6UQhkCLZQrY2sHwlKm0fEjk=";
  };

  ### The daemon renders menus with GTK3 (globalmenu/handlers/global_menu.py
  ### imports Gtk/Gdk with no guard), and it is spawned by the GNOME Shell
  ### extension straight off the session PATH — no desktop file, no GSettings
  ### context to inherit a typelib path from. wrapGAppsHook3 is what puts
  ### GI_TYPELIB_PATH / XDG_DATA_DIRS into the `global-menu` wrapper.
  nativeBuildInputs = [ wrapGAppsHook3 ];
  buildInputs = [ gtk3 ];

  ### buildInputs resolve to gtk3's -dev output, which holds only pkgconfig —
  ### no lib/girepository-1.0. The gobject-introspection env hook therefore
  ### skips it (and the same goes for every other multi-output GTK
  ### dependency), so GI_TYPELIB_PATH would ship without Gtk-3.0.typelib and
  ### the daemon would die on `gi.require_version('Gtk', '3.0')` — then on
  ### Atk, Pango, ... one namespace at a time. Name the runtime typelib dirs
  ### from their out outputs explicitly; `preFixup` runs before wrapGAppsHook
  ### collects gappsWrapperArgs.
  preFixup = ''
    gappsWrapperArgs+=(--prefix GI_TYPELIB_PATH : "${
      lib.makeSearchPathOutput "out" "lib/girepository-1.0" [
        gtk3
        atk
        pango
        gdk-pixbuf
        cairo
      ]
    }")

    ### The daemon forks its reader/service children with
    ### `sys.executable -c "from globalmenu... run()"`
    ### (globalmenu/command.py). nixpkgs' python wrap only patches the parent
    ### script with an in-process site.addsitedir() call, so those children
    ### would start with an empty sys.path and abort with
    ### `ModuleNotFoundError: globalmenu`. Put the same site-packages on
    ### PYTHONPATH instead, so they survive the fork.
    ###
    ### The dependency roots have to be spelled out: recordPropagatedDependencies
    ### only writes $out/nix-support/propagated-build-inputs after fixupOutput
    ### (i.e. after this hook), so `buildPythonPath "$out"` alone would resolve
    ### nothing. The -dev outputs are the ones carrying that file, and it lists
    ### the -out paths of the python deps (pycairo for pygobject3), so the
    ### recursion lands on the real site-packages.
    buildPythonPath "$out ${toString (map lib.getDev propagatedBuildInputs)}"
    gappsWrapperArgs+=(--prefix PYTHONPATH : "$program_PYTHONPATH")
  '';

  propagatedBuildInputs = with python3Packages; [
    pygobject3
    dbus-python
  ];

  ### Upstream runs its suite through `tools/check.sh unit`, i.e. pytest inside
  ### its own dbus-run-session plus a git checkout and the Debian packaging
  ### tree — not a plain `pytest`, so it is not wired up here.
  doCheck = false;

  pythonImportsCheck = [ "globalmenu" ];

  meta = {
    description = "Companion daemon for the Global Menu GNOME Shell extension";
    homepage = "https://github.com/Unmade760/orbit-global-menu";
    license = lib.licenses.gpl3Plus;
    mainProgram = "global-menu";
    platforms = lib.platforms.linux;
  };
}
