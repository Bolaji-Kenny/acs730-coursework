# Midterm Practice -- Notes

## Task 5: git hygiene

<!-- Replace this line with one sentence explaining why deleting the .tfstate
     file and the credential string in your latest commit is not sufficient
     by itself. -->

Deleting the .tfstate file and the credential in a new commit does not remove them from Git history, so anyone with access to the repository can still recover them from earlier commits; the credential must be revoked and rotated, and the history rewritten (e.g. with git filter-repo) if it must be purged.
