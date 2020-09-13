# ideas on idefix

- automated tool which is a team player ( https://ieeexplore.ieee.org/document/1363742 )

## Use cases:

- offer refactoring tools via:
	- editor (1 file/case at a time)
	- command line (change multiple files)
	- work with Credo
- package recommendations / defaults (install a package & do some steps)

## Scenario:

### Automatically fix credo issues (or Elixir warnings)

Let's say you've taken over a project from someone who's new to Elixir and wrote lots of code in the style of their primary language (which is not FP). You add credo and see a gazillion of points to "improve" upon. Next to that the project hasn't been updated and the compiler now shows a lot of warnings (which it didn't at the time of writing). Instead of having to fix them manually you could ask Credo & IDEfix to do it for you, since you're already familiar with the recommendations Credo & Elixir compiler throw at you it feels like a drag to go through each of them yourself.

### Refactoring from editor

Currently the Elixir community offers basic support for most editors, including syntax highlighting, co-operation with compiler (show compiler errors & warnings in editor), but it doesn't offer tools to edit code. Wrangler & RefactorErl are tools for Erlang which do offer refactoring tools, but they down work (well) with tools used by most folks.

### Make use of packages quicker

The Elixir & Erlang eco system is growing well when it comes to offering packages for different kind of problems. Some packages are written for a very specific use case but in order to use them in your project it still requires some effort from the user to integrate them. We feel (some) of that effort could be automated or semi-automated by holding hands when the packages gets installed. Example: add facebook login for you Phoenix project. Steps:
1) add package to mix.exs 2) add some config to config.exs 3) change the plugs pipeline to include facebook auth plug 4) customize screens, errors etc custom to the project. Personally it means I juggle 4 screens: my editor, command line, package readme (with examples) and documentation page (hex docs, for custom options). It would be nice if I can stick to editor & command line until I have something working and docs once I'm ready to make customizations.

## How does it work?

Currently the steps are: parse code into AST -> walk through the AST and replace parts of interest -> turn AST back into code.

## Prior art / inspiration

- [Wrangler](http://refactoringtools.github.io/wrangler/)
- [Atomist](https://atomist.com/)
- [RefactorErl](http://plc.inf.elte.hu/erlang/)
- [JS codemod](https://github.com/cpojer/js-codemod)

## Status

Incomplete (only had a pair of hours this weekend), I wanted to have some examples which involved running credo and then have the issues be autocorrected, however something didn't play well with loading modules on time as the credo runner complains about missing modules. Weird enough I did get it working on another project :(.

So for know it works by calling `mix idefix` and observe the changes to example files (`git diff`).