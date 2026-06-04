# DCEDesignSA
A MATLAB toolbox for generating **Bayesian D-optimal Discrete Choice Experiment (DCE) designs** using Simulated Annealing (SA) optimisation.

---

## Overview

DCEDesignSA generates statistically efficient choice experiment designs by maximising Bayesian D-optimality through a simulated annealing algorithm. The toolbox provides both a graphical user interface (`dce_tool`) and a programmatic API (`DCEDesignSA.generate`) for researchers who need to construct DCE surveys for stated preference studies.

---

## Requirements

- MATLAB R2020b or later
- MATLAB App Designer (included in standard MATLAB installation)
- No additional toolboxes required

---

## Installation

1. Download or clone this repository:
   ```
   git clone https://github.com/YinfuLiu/DCEDesignSA.git
   ```

2. Add the folder to your MATLAB path:
   ```matlab
   addpath('path/to/DCEDesignSA')
   ```

3. Verify installation by running:
   ```matlab
   dce_tool
   ```
   The graphical interface should open.

---

## Quick Start — Graphical Interface

The easiest way to use this toolbox is through the GUI:

```matlab
dce_tool
```

The interface guides you through three steps:

**Step 1 — Attribute Definition**
Define your attributes and their levels. You can rename both attributes and level labels by clicking directly on the table cells.

**Step 2 — Design Settings**
Set the number of choice sets, alternatives per choice set, and optional features such as interaction effects, order effects, partial profiles, and a no-choice alternative.

**Step 3 — Prior Specification**
Specify prior means and variances for your model parameters. These are used to compute the Bayesian D-optimality criterion.

After clicking **Generate**, the tool runs the SA optimisation and displays:
- Summary statistics and level balance
- The design matrix
- Choice probabilities based on the prior

Results can be exported to Qualtrics (`.txt` format) directly from the results window.

---

## Programmatic Usage

You can also call the design generator directly from the MATLAB command line or a script:

```matlab
% Basic example: 3 attributes with 3, 3, and 4 levels
% 12 choice sets, 2 alternatives per set
result = DCEDesignSA.generate(12, 2, 'nlevels', [3 3 4]);

% With named attribute levels
attr_cell.Price     = {{'Low', 'Medium', 'High'}};
attr_cell.Quality   = {{'Poor', 'Average', 'Good'}};
attr_cell.Brand     = {{'A', 'B', 'C', 'D'}};
result = DCEDesignSA.generate(12, 2, 'attr_cell', attr_cell);

% With custom prior and time-limited termination (120 seconds)
result = DCEDesignSA.generate(12, 2, ...
    'nlevels',     [3 3 4], ...
    'prior_mean',  zeros(1, 5), ...
    'prior_var',   eye(5), ...
    'termination', 'time', ...
    'max_value',   120);
```

### Key Parameters

| Parameter | Type | Description |
|---|---|---|
| `cset` | integer | Number of choice sets |
| `n_alt` | integer | Number of alternatives per choice set |
| `nlevels` | vector | Number of levels for each attribute |
| `attr_cell` | struct | Attribute and level names (alternative to `nlevels`) |
| `termination` | string | Stopping criterion: `'adaptive'`, `'time'`, or `'cycle'` |
| `max_value` | numeric | Max seconds or cycles (required for `'time'` and `'cycle'`) |
| `prior_mean` | vector | Prior mean for model parameters (default: zeros) |
| `prior_var` | matrix | Prior covariance matrix (default: identity matrix) |
| `coding` | string | Attribute coding: `'effect'` (default) or `'dummy'` |
| `no_choice` | logical | Include a no-choice alternative (default: `false`) |
| `order_effect` | logical | Model presentation order effects (default: `false`) |
| `interactions` | cell array | Pairs of interacting attributes, e.g. `{[1 2]}` |
| `f` | integer | Number of fixed attributes for partial profiles (default: 0) |

---

## Termination Criteria

The SA optimisation supports three stopping modes:

| Mode | Description | When to use |
|---|---|---|
| `'adaptive'` | Stops when a full cycle produces no further improvement | **Default — produces the most statistically efficient design** |
| `'time'` | Stops after a fixed number of seconds | When you have a strict time budget |
| `'cycle'` | Stops after a fixed number of outer cycles | When you want reproducible runtime |

> **Important note on `adaptive` mode:** The adaptive criterion continues running until no improvement can be found, which makes it the most thorough termination strategy. However, depending on your design complexity (number of attributes, levels, and choice sets), this can take **several minutes to hours**. This is expected behaviour — the algorithm is working correctly. If you need faster results during exploratory analysis, use `'time'` mode with a fixed budget (e.g. `'max_value', 60` for 60 seconds).

---

## Exporting to Qualtrics

After generating a design, you can export it for use in Qualtrics surveys:

```matlab
% Export as Qualtrics text file (long format)
result.export_qualtrics('my_survey');

```


---

## Output

The `generate` function returns a `Result` object with the following methods:

| Method | Description |
|---|---|
| `result.prior_average_prob()` | Displays average choice probabilities |
| `result.export_qualtrics(name)` | Exports design to Qualtrics text format |
| `result.export_csv(name)` | Exports design matrix to CSV |


---

## Citation

If you use this toolbox in your research, please cite it appropriately. A formal citation entry will be added here upon publication.

---

## License

This project is licensed under the MIT License. See `LICENSE` for details.

---

## Author


For questions or bug reports, please open an issue on GitHub.
