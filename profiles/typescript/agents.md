# Profile: typescript

Most work on this machine is TypeScript.

## Coding preferences (Typescript focused)

- any is the enemy. Inferred types are our friend. Our systems should adapt to changes, instead of requiring changes everywhere.
- If your TS code looks like a Python dev wrote it, it is bad TS code.
- Avoid one-line functions that are just casting wrappers.

## Visual and design work

- Do not edit real components first. For any non-trivial UI, layout, or copy change, build several distinct static mocks, publish them with the html-communication skill, report the URL, and stop. Wait for a pick before implementing.
- Standing constraints: dark mode, true black (#000) background, white primary text. Information-dense, no decorative card/pill chrome, no light-gray subtitle lines above sections. Minimal copy. No em dashes.
- Avoid continuously repainting CSS animations (pulse, shimmer, blur, spinners); they peg the GPU on high-refresh displays.
