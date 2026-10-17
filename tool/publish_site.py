"""Publish committed website/ contents to the dedicated gh-pages branch.

Uses the existing Git credential helper. Never changes the checkout/index or
force-pushes. GitHub Pages must be configured for gh-pages / (root).
"""
import argparse
import subprocess


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    subprocess.run(['git', 'diff', '--exit-code', 'HEAD', '--', 'website'], check=True)
    if git('ls-files', '--others', '--exclude-standard', 'website'):
        raise SystemExit('Commit all website files before publishing.')
    tree = git('rev-parse', 'HEAD:website')
    if args.dry_run:
        print(f'Would publish website tree {tree} to origin/gh-pages; no remote changes.')
        return
    subprocess.run(['git', 'fetch', 'origin', 'gh-pages'], check=True)
    parent = git('rev-parse', 'FETCH_HEAD')
    if tree == git('rev-parse', f'{parent}^{{tree}}'):
        print('The published branch already has this website content.')
        return
    commit = git('commit-tree', tree, '-p', parent, '-m', 'Update LeanDaily privacy and support pages')
    subprocess.run(['git', 'push', 'origin', f'{commit}:refs/heads/gh-pages'], check=True)
    print('Pushed. Wait for the GitHub Pages deployment and verify public URLs.')


if __name__ == '__main__':
    main()
