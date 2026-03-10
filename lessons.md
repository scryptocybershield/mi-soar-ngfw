# Lessons Learned

## Leccion 9: Least Privilege Principle in CI/CD

Patron: Los workflows de GitHub Actions tienen permisos restringidos por defecto.

Regla: Si una accion necesita interactuar con la API de GitHub (por ejemplo, subir reportes SARIF a la pestana Security o comentar en pull requests), se deben declarar permisos explicitos en el job, incluyendo `security-events: write` cuando corresponda.
