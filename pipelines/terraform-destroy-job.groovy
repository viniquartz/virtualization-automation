// Jenkins Pipeline Job - VMware Terraform Destroy
// Copy this script directly into Jenkins Pipeline job configuration
// Use for decommissioning VMware infrastructure

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
        booleanParam(
            name: 'CONFIRM_DESTROY',
            defaultValue: false,
            description: '⚠️ Check to confirm destruction'
        )
    }
    
    environment {
        PROJECT_DISPLAY_NAME = "${params.TICKET_ID}-${params.ENVIRONMENT}"
        
        // Azure credentials for backend
        ARM_CLIENT_ID = credentials("azure-sp-${params.ENVIRONMENT}-client-id")
        ARM_CLIENT_SECRET = credentials("azure-sp-${params.ENVIRONMENT}-client-secret")
        ARM_SUBSCRIPTION_ID = credentials("azure-sp-${params.ENVIRONMENT}-subscription-id")
        ARM_TENANT_ID = credentials("azure-sp-${params.ENVIRONMENT}-tenant-id")
        
        // vSphere credentials
        VSPHERE_USER = credentials("vsphere-${params.ENVIRONMENT}-user")
        VSPHERE_PASSWORD = credentials("vsphere-${params.ENVIRONMENT}-password")
        VSPHERE_SERVER = credentials("vsphere-${params.ENVIRONMENT}-server")
    }
    
    stages {
        stage('Validation') {
            steps {
                script {
                    if (!params.CONFIRM_DESTROY) {
                        error "[ERROR] CONFIRM_DESTROY must be checked to proceed with destruction"
                    }
                    
                    echo "=========================================="
                    echo "⚠️  DESTRUCTION WARNING ⚠️"
                    echo "=========================================="
                    echo "Ticket ID:    ${params.TICKET_ID}"
                    echo "Environment:  ${params.ENVIRONMENT}"
                    echo "Action:       DESTROY ALL INFRASTRUCTURE"
                    echo "=========================================="
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
                        terraform init -backend-config=backend-config.tfbackend
                    """
                }
            }
        }
        
        stage('Current State') {
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[INFO] Checking current infrastructure state"
                        terraform show
                        
                        echo ""
                        echo "[INFO] Resources to be destroyed:"
                        terraform state list || echo "No resources found in state"
                    """
                }
            }
        }
        
        stage('Destroy Plan') {
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[PLAN] Creating destruction plan for ${PROJECT_DISPLAY_NAME}"
                        terraform plan -destroy \\
                            -out=tfplan-destroy-${PROJECT_DISPLAY_NAME} \\
                            -var-file='environments/${params.ENVIRONMENT}/terraform.tfvars' \\
                            -var='vsphere_server='\$VSPHERE_SERVER \\
                            -var='vsphere_user='\$VSPHERE_USER \\
                            -var='vsphere_password='\$VSPHERE_PASSWORD
                        
                        echo "[PLAN] Saving plan to JSON"
                        terraform show -json tfplan-destroy-${PROJECT_DISPLAY_NAME} > tfplan-destroy-${PROJECT_DISPLAY_NAME}.json
                    """
                }
            }
        }
        
        stage('Final Approval') {
            steps {
                script {
                    def approvalMessage = "⚠️ FINAL CONFIRMATION: Destroy ALL infrastructure for ${PROJECT_DISPLAY_NAME}?"
                    def approvers = 'infrastructure-leads'
                    def timeoutHours = 4
                    
                    // Production requires C-level approval
                    if (params.ENVIRONMENT == 'prd') {
                        approvalMessage = "🔴 PRODUCTION DESTRUCTION: Approve complete removal of ${PROJECT_DISPLAY_NAME}?"
                        approvers = 'c-level-executives,infrastructure-leads'
                        timeoutHours = 8
                    }
                    
                    echo "[APPROVAL] ⚠️ FINAL APPROVAL REQUIRED ⚠️"
                    echo "[APPROVAL] Waiting for approval from: ${approvers}"
                    echo "[APPROVAL] Timeout: ${timeoutHours} hours"
                    
                    timeout(time: timeoutHours, unit: 'HOURS') {
                        input(
                            message: approvalMessage,
                            ok: "⚠️ CONFIRM DESTRUCTION ⚠️",
                            submitter: approvers
                        )
                    }
                    
                    echo "[APPROVAL] Destruction approved for ${PROJECT_DISPLAY_NAME}"
                    
                    // Additional 30-second pause before destruction
                    echo "[PAUSE] 30-second safety pause before destruction..."
                    sleep(time: 30, unit: 'SECONDS')
                }
            }
        }
        
        stage('Terraform Destroy') {
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[DESTROY] Destroying infrastructure for ${PROJECT_DISPLAY_NAME}"
                        echo "[DESTROY] Starting destruction in 5 seconds..."
                        sleep 5
                        
                        terraform apply -auto-approve tfplan-destroy-${PROJECT_DISPLAY_NAME}
                        
                        echo "[OK] Infrastructure destroyed for ${PROJECT_DISPLAY_NAME}"
                    """
                }
            }
        }
        
        stage('Verify Destruction') {
            steps {
                dir('terraform-project-template') {
                    sh """
                        echo "[VERIFY] Verifying complete destruction"
                        
                        REMAINING_RESOURCES=\$(terraform state list | wc -l)
                        
                        if [ "\$REMAINING_RESOURCES" -eq "0" ]; then
                            echo "[OK] All resources successfully destroyed"
                        else
                            echo "[WARNING] Some resources may remain in state:"
                            terraform state list
                        fi
                    """
                }
            }
        }
        
        stage('Cleanup State') {
            steps {
                dir('terraform-project-template') {
                    script {
                        def shouldCleanup = input(
                            message: "Remove Terraform state file from Azure Storage?",
                            ok: "Yes, remove state",
                            parameters: [
                                booleanParam(
                                    name: 'REMOVE_STATE',
                                    defaultValue: true,
                                    description: 'Remove state file after destruction'
                                )
                            ]
                        )
                        
                        if (shouldCleanup) {
                            sh """
                                echo "[CLEANUP] Removing state file from Azure Storage"
                                
                                az storage blob delete \\
                                    --account-name azrprdiac01weust01 \\
                                    --container-name terraform-state-${params.ENVIRONMENT} \\
                                    --name vmware/${params.TICKET_ID}.tfstate \\
                                    --auth-mode login || true
                                
                                echo "[OK] State file removed"
                            """
                        } else {
                            echo "[SKIP] State file preserved in Azure Storage"
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "=========================================="
                echo "[SUCCESS] Infrastructure destroyed"
                echo "=========================================="
                echo "Ticket ID:    ${params.TICKET_ID}"
                echo "Environment:  ${params.ENVIRONMENT}"
                echo "Status:       DESTROYED"
                echo "Build URL:    ${env.BUILD_URL}"
                echo "=========================================="
            }
        }
        
        failure {
            script {
                echo "=========================================="
                echo "[FAILURE] Destruction failed"
                echo "=========================================="
                echo "Ticket ID:    ${params.TICKET_ID}"
                echo "Environment:  ${params.ENVIRONMENT}"
                echo "Status:       FAILED"
                echo "Build URL:    ${env.BUILD_URL}"
                echo "=========================================="
                echo "[ACTION REQUIRED] Manual intervention may be needed"
            }
        }
        
        always {
            // Archive destruction plan and reports
            archiveArtifacts artifacts: '**/tfplan-destroy-*', allowEmptyArchive: true
            
            cleanWs()
        }
    }
}
