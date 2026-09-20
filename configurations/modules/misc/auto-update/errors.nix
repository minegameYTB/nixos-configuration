# configurations/modules/misc/auto-update/errors.nix — single source of truth
# for every user-visible auto-update error (journal + desktop notification).
#
# Contract:
#   `catalog` maps a machine-readable CODE to { urgency, title_fr, body_fr,
#   title_en, body_en }. `toBash catalog` renders the `_err_lookup CODE FIELD`
#   shell helper consumed by `_fail` (transaction.nix).
#   FIELD is one of: urgency, title_fr, body_fr, title_en, body_en.
#
# Rules (enforced by construction, checked by test-auto-update-sh.sh):
#   messages are static text — no `$`, backticks, double quotes or `''`
#   sequences ( Nix `''` strings + bash `printf '%s' "..."` ). Dynamic detail
#   (rev, path) is appended by `_fail` from its extra arguments, never from
#   the catalogue. Keep doc/auto-update.md troubleshooting in sync (1 CODE =
#   1 row).
{ lib }:

let
  fields = [
    "urgency"
    "title_fr"
    "body_fr"
    "title_en"
    "body_en"
  ];

  lineFor =
    code: field:
    let
      text = builtins.getAttr field (builtins.getAttr code catalog);
    in
    ''      ${code}:${field}) printf '%s' "${text}" ;;'';

  catalog = {
    channel-resolve = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Canal introuvable";
      body_fr = "Impossible de résoudre la révision du canal. Réseau ou forge injoignable, nouvel essai au prochain passage.";
      title_en = "NixOS Update — Channel resolution failed";
      body_en = "Could not resolve the channel revision. Network or forge unreachable, will retry on next run.";
    };

    flake-sync = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Échec réseau";
      body_fr = "Impossible de récupérer l’arbre du canal (fetch incrémental puis re-clonage ont échoué). Voir le journal.";
      title_en = "NixOS Update — Network failure";
      body_en = "Could not fetch the channel tree (incremental fetch then re-clone both failed). See the journal.";
    };

    flake-lock-missing = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Arbre invalide";
      body_fr = "Le fichier flake.lock est absent de l’arbre synchronisé. Synchronisation abandonnée.";
      title_en = "NixOS Update — Invalid tree";
      body_en = "The flake.lock file is missing from the synced tree. Sync aborted.";
    };

    flake-update = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Entrées introuvables";
      body_fr = "La mise à jour des entrées du flake a échoué plusieurs fois. Réseau ou source injoignable, voir le journal.";
      title_en = "NixOS Update — Inputs update failed";
      body_en = "Updating the flake inputs failed repeatedly. Network or source unreachable, see the journal.";
    };

    local-pull = {      urgency = "normal";
      title_fr = "Mise à jour NixOS — Checkout local ignoré";
      body_fr = "Le checkout local est absent, sale ou hors branche : repli sur la référence distante.";
      title_en = "NixOS Update — Local checkout skipped";
      body_en = "The local checkout is missing, dirty or off-branch: falling back to the remote ref.";
    };

    rebuild-boot = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Reconstruction échouée";
      body_fr = "La reconstruction du système a échoué. La génération en cours est conservée, voir le journal.";
      title_en = "NixOS Update — Rebuild failed";
      body_en = "System rebuild failed. The running generation is kept, see the journal.";
    };

    disk-space = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Disque insuffisant";
      body_fr = "Pas assez d’espace libre sur le store pour démarrer la mise à jour. Libérez de l’espace et réessayez.";
      title_en = "NixOS Update — Insufficient disk space";
      body_en = "Not enough free space on the store to start the update. Free some space and retry.";
    };

    network-offline = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Réseau indisponible";
      body_fr = "Aucune connectivité après la période d’attente. Nouvel essai au prochain passage.";
      title_en = "NixOS Update — Network offline";
      body_en = "No connectivity after the waiting period. Will retry on next run.";
    };

    state-error = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — État incohérent";
      body_fr = "L’état interne de mise à jour est corrompu. Intervention manuelle requise, voir le journal.";
      title_en = "NixOS Update — Inconsistent state";
      body_en = "The updater internal state is inconsistent. Manual action required, see the journal.";
    };

    boot-recovery = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Reprise incomplète";
      body_fr = "La reprise ou la restauration automatique n’a pas abouti. Nouvel essai au prochain lancement.";
      title_en = "NixOS Update — Incomplete recovery";
      body_en = "Automatic recovery or restoration did not complete. It will be retried on the next run.";
    };

    boot-recovery-rolled-back = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Ancien système restauré";
      body_fr = "L’installation au démarrage n’a pas pu être terminée. La nouvelle génération a été abandonnée et l’ancien système a été restauré.";
      title_en = "NixOS Update — Previous system restored";
      body_en = "Boot installation could not be completed. The new generation was abandoned and the previous system was restored.";
    };

    healthcheck-failed = {
      urgency = "critical";
      title_fr = "Mise à jour NixOS — Démarrage malsain";
      body_fr = "La génération staged ne passe pas la validation post-démarrage. Mises à jour inhibées jusqu’à action manuelle.";
      title_en = "NixOS Update — Unhealthy boot";
      body_en = "The staged generation failed post-boot validation. Updates inhibited until manual action.";
    };
  };
in
{
  inherit catalog;

  toBash =
    { }:
    let
      codes = builtins.attrNames catalog;
      lines = lib.concatLists (map (code: map (field: lineFor code field) fields) codes);
    in
    ''
      # >>>BEGIN errors
      _err_lookup() {
        local code="$1" field="$2"
        case "$code:$field" in
      ${lib.concatStringsSep "\n" lines}
          *) printf '%s' "" ;;
        esac
      }
      # <<<END errors
    '';
}
