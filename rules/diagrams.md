# Diagrams

Draw diagrams with Graphviz or gnuplot. Mermaid, PlantUML and ASCII art are
out unless asked for by name: their layout engines give no control over
ranking, clustering, edge routing or styling.

- **Structure** (graphs, flows, topologies, dependencies, state machines,
  hierarchies): Graphviz. Write a `.dot` file and render with the engine that
  fits the shape: `dot` for layered/directed, `neato`/`fdp` for undirected
  networks, `circo` for rings, `twopi` for radial, `osage`/`patchwork` for
  packed clusters. Use `subgraph cluster_*`, `rank=same`, `rankdir`, HTML-like
  labels and ports when the layout needs them.
- **Data** (time series, distributions, functions, anything with axes):
  gnuplot. Write a `.gp` script and render with `gnuplot script.gp`.
- **Output**: SVG by default (`dot -Tsvg`, `set terminal svg`), PNG only where
  SVG does not render. Keep the source file next to the rendered one so the
  diagram can be edited and re-rendered.
- **Inside an Artifact**: render to SVG and inline it, so the page stays one
  file, and set colours from the page's tokens.
