# Environment-Specific Configuration

Each environment (tst, qlt, prd) has its own `terraform.tfvars` file with environment-specific values.

## Usage

### Deploy to Test Environment

```bash
# From project root
terraform plan -var-file="environments/tst/terraform.tfvars"
terraform apply -var-file="environments/tst/terraform.tfvars"
```

### Deploy to Quality Environment

```bash
terraform plan -var-file="environments/qlt/terraform.tfvars"
terraform apply -var-file="environments/qlt/terraform.tfvars"
```

### Deploy to Production Environment

```bash
terraform plan -var-file="environments/prd/terraform.tfvars"
terraform apply -var-file="environments/prd/terraform.tfvars"
```

## Configuration Guidelines

### Test Environment (tst)

- Lower resource allocation
- Relaxed security (allow_unverified_ssl = true)
- Used for initial testing and validation

### Quality Environment (qlt)

- Medium resource allocation
- Pre-production validation
- Performance and integration testing

### Production Environment (prd)

- Full resource allocation
- Strict security (allow_unverified_ssl = false)
- Store sensitive values in Azure Key Vault
- Requires approval for changes

## Security Best Practices

**IMPORTANT:** Never commit sensitive credentials to Git!

1. **Use environment variables:**

   ```bash
   export TF_VAR_vsphere_password="secure-password"
   export TF_VAR_windows_admin_password="secure-password"
   ```

2. **Use Azure Key Vault:**
   - Store vSphere credentials in Key Vault
   - Reference via data source in Terraform

3. **Use CI/CD secrets:**
   - Store in Jenkins Credentials
   - Inject as environment variables in pipeline

4. **Rotate credentials regularly**

## Customization

Copy and modify values for your environment:

```bash
cp environments/tst/terraform.tfvars environments/tst/terraform.tfvars.local
# Edit terraform.tfvars.local with your values
# Use: terraform plan -var-file="environments/tst/terraform.tfvars.local"
```

Note: `*.tfvars.local` is ignored by Git (.gitignore)
