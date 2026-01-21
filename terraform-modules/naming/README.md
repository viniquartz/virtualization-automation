# Naming Convention Module

Generates standardized VM names following the pattern: `<purpose><environment><instance>`

## Pattern

- **Format:** `<purpose>-<environment>-<instance>`
- **Max Length:** 15 characters (configurable)
- **Example:** `web-tst-01`, `app-prd-03`, `db-qlt-02`

## Usage

```hcl
module "vm_naming" {
  source = "../terraform-modules/naming"
  
  purpose         = "web"
  environment     = "tst"
  instance_number = 1
  max_name_length = 15
}

output "vm_name" {
  value = module.vm_naming.vm_name  # Returns: web-tst-01
}
```

## Variables

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| purpose | string | Yes | - | VM purpose (2-8 chars, lowercase) |
| environment | string | Yes | - | Environment (prd/qlt/tst) |
| instance_number | number | No | 1 | Instance number (1-99) |
| max_name_length | number | No | 15 | Maximum name length |

## Outputs

| Name | Description |
|------|-------------|
| vm_name | Generated VM name |
| hostname | Generated hostname (same as vm_name) |
| name_length | Length of generated name |

## Examples

### Web Server

```hcl
module "web_naming" {
  source          = "../terraform-modules/naming"
  purpose         = "web"
  environment     = "prd"
  instance_number = 1
}
# Output: web-prd-01
```

### Database Server

```hcl
module "db_naming" {
  source          = "../terraform-modules/naming"
  purpose         = "db"
  environment     = "tst"
  instance_number = 5
}
# Output: db-tst-05
```

### Application Server

```hcl
module "app_naming" {
  source          = "../terraform-modules/naming"
  purpose         = "app"
  environment     = "qlt"
  instance_number = 10
}
# Output: app-qlt-10
```

## Validation Rules

1. **Purpose:** 2-8 characters, lowercase alphanumeric with hyphens
2. **Environment:** Must be `prd`, `qlt`, or `tst`
3. **Instance:** 1-99
4. **Total Length:** Must not exceed max_name_length (default 15)

## Requirements

- Terraform >= 1.5.0
