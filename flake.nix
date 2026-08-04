{
  description = "katagami 開発環境";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # backend Python 環境の Nix build 化。
    # uv.lock（正本: backend/pyproject.toml + uv.lock）から
    # Python パッケージ一式を Nix derivation として構成する。
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, pyproject-nix, uv2nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        # --- backend Python 環境（uv2nix） ---
        # backend/pyproject.toml + uv.lock を読み、依存を Nix build で構成する。
        # backend は virtual project（[tool.uv] package = false）のため、
        # mkVirtualEnv には依存のみが入る（app/ 本体は PYTHONPATH/cwd で解決）。
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./backend; };
        # wheel 優先: uv.lock に記録された wheel をそのまま使い、sdist ビルドの
        # ツールチェーン差異（Rust / cmake 等）を持ち込まない
        pyprojectOverlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python313; # Python 3.13（requires-python 準拠）
          }).overrideScope (lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            pyprojectOverlay
          ]);
        # 全依存入りの virtualenv（devshell の python / pytest / ruff の実体）
        backendEnv = pythonSet.mkVirtualEnv "katagami-backend-env" workspace.deps.default;

        # --- web Node.js 環境（importNpmLock） ---
        # web/package-lock.json を正として node_modules を Nix build で構成する
        # （backend の uv2nix と同じ思想。npm install で node_modules を作らない）。
        # 依存の tarball は lock の integrity ハッシュで固定取得される（供給網保護）。
        nodejs = pkgs.nodejs_22;
        webNodeModules = pkgs.importNpmLock.buildNodeModules {
          npmRoot = ./web;
          inherit nodejs;
        };
        # --- テンプレート生成 CLI（ADR-0002 / ADR-0003） ---
        # `nix run .#new -- <app名>` でこのリポジトリをテンプレートとして新プロジェクトを
        # 生成する。テンプレートの実体は self（= このリポジトリの git 管理ファイル一式）で、
        # 生成ロジックは scripts/new-project.sh が正本。
        newProject = pkgs.writeShellApplication {
          name = "katagami-new";
          runtimeInputs = with pkgs; [ git gnused gnutar gnugrep gawk findutils coreutils ];
          text = ''
            export KATAGAMI_TEMPLATE_ROOT=${self}
            exec bash ${self}/scripts/new-project.sh "$@"
          '';
        };
      in
      {
        packages = {
          backend-env = backendEnv;
          web-node-modules = webNodeModules;
          new-project = newProject;
        };

        apps.new = {
          type = "app";
          program = "${newProject}/bin/katagami-new";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            # --- Python (Backend) ---
            # uv2nix で build した全依存入り virtualenv（.venv は作らない）。
            # python / pytest / ruff / uvicorn 等はここから PATH に載る
            backendEnv
          ] ++ (with pkgs; [
            uv                 # uv.lock の更新（uv lock）専用。依存導入には使わない

            # --- Node.js (Frontend) ---
            # npm は package-lock.json の更新（npm install --package-lock-only）専用。
            # node_modules の実体は webNodeModules（Nix build）が提供する
            nodejs

            # --- IaC ---
            opentofu           # OpenTofu CLI（Terraform 互換 / インフラ管理）

            # --- 共通ツール ---
            git
            gh                 # GitHub CLI
            curl
            gnumake
          ]);

          shellHook = ''
            # web/node_modules を Nix build（importNpmLock）の成果物へ symlink する。
            # npm install で作られた実体ディレクトリが残っていたら Nix 管理へ置き換える
            if [ -e web/node_modules ] && [ ! -L web/node_modules ]; then
              echo "web/node_modules が Nix 管理外の実体です。Nix build の symlink へ置き換えます"
              rm -rf web/node_modules
            fi
            ln -sfn ${webNodeModules}/node_modules web/node_modules

            echo ""
            echo "katagami 開発環境"
            echo "  Python : $(python3 --version) (nix build: katagami-backend-env)"
            echo "  Node   : $(node --version)"
            echo "  npm    : $(npm --version)"
            echo "  uv     : $(uv --version)"
            echo "  gh     : $(gh --version | head -1)"
            echo ""
            echo "セットアップ: make setup"
            echo ""
          '';
        };
      }
    );
}
