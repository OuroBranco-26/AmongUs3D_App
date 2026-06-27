# AmongUs 3D

Projeto em desenvolvimento de um clone 3D de Among Us, otimizado para PC e Android.

## Metas do Projeto
- Motor Gráfico: Godot Engine 4 (Renderizador Mobile)
- Câmera: Sistema Híbrido (Alternância entre 1ª Pessoa e 3ª Pessoa).
- Na 3ª Pessoa, usaremos um nó `SpringArm3D` para garantir que a câmera encoste nas paredes e não atravesse o mapa, mantendo a sensação claustrofóbica do jogo.
- Oclusão e Visão: Jogadores não conseguirão ver quem está escondido atrás de paredes, respeitando as regras do jogo original.
