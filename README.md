# AI Skills

Registre personnel de skills pour agents IA (Claude Code et compatibles).
Chaque skill est un dossier autonome sous `skills/<nom>/`, avec un `SKILL.md`
(frontmatter `name` + `description`) et, si besoin, un dossier `references/`
chargé à la demande.

## Skills

| Skill | Description |
|---|---|
| [git-worktree-management](skills/git-worktree-management/SKILL.md) | Isole des worktrees Git parallèles (ports, conteneurs, base de données, fichiers non versionnés) et expose des commandes `wt-*` uniformes sur Make, Just ou Task. Le runtime est un script bash, sans LLM. |

## Installation

Copier ou lier le dossier d'une skill dans le répertoire de skills de l'agent :

```bash
# Skill disponible pour tous les projets (utilisateur)
ln -s "$(pwd)/skills/git-worktree-management" ~/.claude/skills/git-worktree-management

# Ou limitée à un projet
ln -s "$(pwd)/skills/git-worktree-management" /chemin/du/projet/.claude/skills/git-worktree-management
```

## Ajouter une skill

1. Créer `skills/<nom-en-kebab-case>/SKILL.md` avec un frontmatter :
   ```markdown
   ---
   name: <nom-en-kebab-case>
   description: <ce que fait la skill et quand la déclencher>
   ---
   ```
2. Placer les ressources annexes (templates, scripts, catalogues) dans `references/`
   et les citer depuis `SKILL.md` pour qu'elles ne soient lues qu'au besoin.
3. Ajouter une ligne au tableau ci-dessus.
4. Ne jamais commiter de secret (`.env`, jetons, clés) dans une skill.
