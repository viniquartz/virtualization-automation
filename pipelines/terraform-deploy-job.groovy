// Jenkins Pipeline Job - VMware Terraform Deploy
// Copy this script directly into Jenkins Pipeline job configuration

pipeline {
    agent {
        label 'terraform-agent'
    }
    
    parameters {
        string(
            name: 'TICKET_ID',
            description: 'Jira ticket ID (e.g., OPS-1234)'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['tst', 'qlt', 'prd'],
            description: 'Target environment'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply'],
            description: 'Terraform action'
        )
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'main',
            description: 'Repository branch'
        )
        string(
            name: 'GIT_REPO_URL',
            defaultValue: 'https://github.com/your-org/virtualization-automation.git',
            description: 'Full Git repository URL'
        )
    }
    
    environment {
        PROJECT_DISPLAY_NAME = "${params.TICKET_ID}-${params.ENVIRONMENT}"
        
        // Azure credentials for backend (environment-specific)
        ARM_CLIENT_ID = credentials("azure-sp-${params.ENVIRONMENT}-client-id")
        ARM_CLIENT_SECRET = credentials("azure-sp-${params.ENVIRONMENT}-client-secret")
        ARM_SUBSCRIPTION_ID = credentials("azure-sp-${params.ENVIRONMENT}-subscription-id")
        ARM_TENANT_ID = credentials("azure-sp-${params.ENVIRONMENT}-tenant-id")
        
        // vSphere credentials (environment-specific)
        VSPHERE_USER = credentials("vsphere-${params.ENVIRONMENT}-user")
        VSPHERE_PASSWORD = credentials("vsphere-${params.ENVIRONMENT}-password")
        VSPHERE_SERVER = credentials("vsphere-${params.ENVIRONMENT}-server")
    }
    
    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "[START] Starting deployment for ${PROJECT_DISPLAY_NAME}"
                    echo "[INFO] Using Azure Service Principal for backend: ${params.ENVIRONMENT}"
                    echo "[INFO] Target vSphere environment: ${params.ENVIRONMENT}"
                }
            }
        }
        
        stage('Checkout') {
            steps {
                script {
                    echo "[CHECKOUT] Cloning ${params.TICKET_ID} from ${params.GIT_REPO_URL}"
                    echo "[CHECKOUT] Branch: ${params.GIT_BRANCH}"
                    
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: params.GIT_BRANCH]],
                        userRemoteConfigs: [[
                            url: params.GIT_REPO_URL,
                            credentialsId: 'git-credentials'
                        ]]
                    ])
                }
            }
        }
        
        stage('Validate') {
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[VALIDATE] Validating Terraform code for ${PROJECT_DISPLAY_NAME}"
                        terraform fmt -check -recursive
                        terraform init -backend=false
                        terraform validate
                    """
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                sh """
                    echo "[SCAN] Running Trivy security scan for ${PROJECT_DISPLAY_NAME}"
                    
                    trivy config terraform-project-template/ \\
                        --format sarif \\
                        --output trivy-report-${PROJECT_DISPLAY_NAME}.sarif \\
                        --severity MEDIUM,HIGH,CRITICAL || true
                    
                    trivy convert --format template --template '@contrib/junit.tpl' \\
                        trivy-report-${PROJECT_DISPLAY_NAME}.sarif > trivy-report-${PROJECT_DISPLAY_NAME}.xml || true
                    
                    echo "[OK] Security scan completed"
                """
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[INIT] Configuring backend for ${PROJECT_DISPLAY_NAME}"
                        
                        # Azure login with Service Principal
                        az login --service-principal \\
                            --username \$ARM_CLIENT_ID \\
                            --password \$ARM_CLIENT_SECRET \\
                            --tenant \$ARM_TENANT_ID
                        
                        az account set --subscription \$ARM_SUBSCRIPTION_ID
                        
                        # Generate dynamic backend configuration
                        cat > backend-config.tfbackend << EOF
resource_group_name  = "azr-prd-iac01-weu-rg"
storage_account_name = "azrprdiac01weust01"
container_name       = "terraform-state-${params.ENVIRONMENT}"
key                  = "vmware/${params.TICKET_ID}.tfstate"
EOF
                        
                        echo "[INIT] Initializing Terraform with backend config"
                        terraform init -backend-config=backend-config.tfbackend -upgrade
                    """
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('terraform-project-template') {
                    script {
                        echo "[PLAN] Running Terraform plan for ${PROJECT_DISPLAY_NAME}"
                        
                        def planExitCode = sh(
                            script: """
                                terraform plan \\
                                    -out=tfplan-${PROJECT_DISPLAY_NAME} \\
                                    -var-file='environments/${params.ENVIRONMENT}/terraform.tfvars' \\
                                    -var='vsphere_server='\$VSPHERE_SERVER \\
                                    -var='vsphere_user='\$VSPHERE_USER \\
                                    -var='vsphere_password='\$VSPHERE_PASSWORD \\
                                    -detailed-exitcode
                            """,
                            returnStatus: true
                        )
                        
                        if (planExitCode == 2) {
                            echo "[WARNING] Changes detected for ${PROJECT_DISPLAY_NAME}"
                        } else if (planExitCode == 0) {
                            echo "[OK] No changes required for ${PROJECT_DISPLAY_NAME}"
                        } else {
                            error "[ERROR] Terraform plan failed for ${PROJECT_DISPLAY_NAME}"
                        }
                        
                        sh "terraform show -json tfplan-${PROJECT_DISPLAY_NAME} > tfplan-${PROJECT_DISPLAY_NAME}.json"
                    }
                }
            }
        }
        
        stage('Approval') {
            when {
                expression { 
                    params.ACTION == 'apply'
                }
            }
            steps {
                script {
                    def approvalMessage = "Approve ${params.ACTION} for ${PROJECT_DISPLAY_NAME}?"
                    def approvers = 'devops-team'
                    def timeoutHours = 2
                    
                    // Production requires additional approval
                    if (params.ENVIRONMENT == 'prd') {
                        approvalMessage = "🔴 PRODUCTION: Approve ${params.ACTION} for ${PROJECT_DISPLAY_NAME}?"
                        approvers = 'infrastructure-leads'
                        timeoutHours = 4
                    }
                    
                    echo "[APPROVAL] Waiting for approval from: ${approvers}"
                    echo "[APPROVAL] Timeout: ${timeoutHours} hours"
                    
                    timeout(time: timeoutHours, unit: 'HOURS') {
                        input(
                            message: approvalMessage,
                            ok: "Approve Deploy",
                            submitter: approvers
                        )
                    }
                    
                    echo "[APPROVAL] Deployment approved for ${PROJECT_DISPLAY_NAME}"
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { 
                    params.ACTION == 'apply'
                }
            }
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[APPLY] Applying Terraform changes for ${PROJECT_DISPLAY_NAME}"
                        terraform apply -auto-approve tfplan-${PROJECT_DISPLAY_NAME}
                        echo "[OK] Infrastructure deployed for ${PROJECT_DISPLAY_NAME}"
                    """
                }
            }
        }
        
        stage('Output') {
            when {
                expression { 
                    params.ACTION == 'apply'
                }
            }
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[OUTPUT] Terraform outputs for ${PROJECT_DISPLAY_NAME}"
                        terraform output -json > terraform-outputs-${PROJECT_DISPLAY_NAME}.json
                        terraform output
                    """
                }
            }
        }
    }
    
    post {
        success {
            script {
                def message = params.ACTION == 'apply' ? 
                    "[SUCCESS] Infrastructure deployed for ${PROJECT_DISPLAY_NAME}" : 
                    "[SUCCESS] Plan completed for ${PROJECT_DISPLAY_NAME}"
                
                echo message
                echo "[INFO] Build URL: ${env.BUILD_URL}"
            }
        }
        
        failure {
            script {
                echo "[FAILURE] Deployment failed for ${PROJECT_DISPLAY_NAME}"
                echo "[INFO] Check logs for details"
                echo "[INFO] Build URL: ${env.BUILD_URL}"
            }
        }
        
        always {
            // Archive Terraform files and reports
            archiveArtifacts artifacts: '**/*-report.*,**/tfplan-*,**/terraform-outputs-*.json', allowEmptyArchive: true
            
            // Publish JUnit test results
            junit testResults: '**/*-report.xml', allowEmptyResults: true
            
            cleanWs()
        }
    }
}
