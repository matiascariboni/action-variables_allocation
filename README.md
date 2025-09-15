# 📦 Variables Allocation

This GitHub Action replaces environment variable placeholders defined in an input file (`ENV_FILE_IN`) using repository `secrets` and `vars`. It also extracts the CloudFront distribution ID (`CLOUDFRONT_DIST_ID`) and outputs it for use in subsequent steps.

> Ideal for AWS deployment workflows, environment-based configuration, and secrets-driven `.env` generation.

---

## ✨ Features

* 🪧 Replaces placeholders like `'{MY_SECRET}'` with actual values from `secrets` or `vars`
* 🔄 Supports branch-prefixed variables (`main_MY_SECRET`, etc.)
* 📤 Exposes `CLOUDFRONT_DIST_ID` as an output
* 📄 Writes a ready-to-use `.env` or configuration file

---

## 📂 Expected Input Format

The input file (`ENV_FILE_IN`) should contain lines with variables in this format:

```env
API_KEY='{API_KEY}'
SOME_FLAG='true'
```

Braces (`'{...}'`) will be replaced with actual values from GitHub repository secrets or variables.

---

## 🧠 Usage

### 1. Add a template file `.env.in`:

```env
API_URL='{API_URL}'
SECRET_TOKEN='{SECRET_TOKEN}'
```

### 2. Define values in your GitHub repository as `secrets` or `vars`

You can define global or branch-specific variables, such as:

* `MASTER_API_URL`
* `DEV_SECRET_TOKEN`

### 3. Use the Action in your workflow:

```yaml
jobs:
  generate_env:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Variable allocation & CLOUDFRONT_DIST_ID
        id: variables_allocation
        uses: matiascariboni/action-variables_allocation@v1.2.0
        with:
          env_file_in: ${{ env.ENV_FILE_IN }}
          env_file_out: ${{ env.ENV_FILE_OUT }}
          repo_vars: ${{ toJson(vars) }}
          repo_secrets: ${{ toJson(secrets) }}

      - name: Print output
        run: echo "CloudFront ID: ${{ steps.variables_allocation.outputs.CLOUDFRONT_DIST_ID }}"
```

---

## 👇🏻 Inputs

| Name           | Description                                       | Required  |
| -------------- | ------------------------------------------------- | --------- |
| `env_file_in`  | Path to input file with `'{}'`-style placeholders | ✅ Yes    |
| `env_file_out` | Path to save the output file with resolved values | ✅ Yes    |
| `repo_vars`    | Variables allocated on current repo               | ✅ Yes    |
| `repo_secrets` | Variables allocated on current secret             | ✅ Yes    |

---

## 🔄 Outputs

| Name                 | Description                             |
| -------------------- | --------------------------------------- |
| `CLOUDFRONT_DIST_ID` | The resolved CloudFront distribution ID |

---

## ⚠️ Variable resolution order

1. `${BRANCH}_VAR_NAME` in **secrets**
2. `${BRANCH}_VAR_NAME` in **vars**
3. `VAR_NAME` in **secrets**
4. `VAR_NAME` in **vars**

---

## ⚖️ Special rules

* Lines starting with `//` are ignored (treated as comments)
* If a value is not found, the step fails explicitly (except `CLOUDFRONT_DIST_ID`, which is optional)
* If the output file ends with `.json`, values are always written as JSON strings
* Prefix `~` inside a placeholder (e.g., `'~{VAR}'`) means the value will be inserted **without quotes**
* Arrays like `[1,2,3]` are detected and preserved as raw values
* If the value is not a number, boolean, array, or prefixed with `~`, it is wrapped in single quotes (`'value'`)

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or pull requests.

---

## ✍ Author

Developed by [Matías Cariboni](https://github.com/matiascariboni).
