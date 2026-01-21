// Jenkins Pipeline Job - VMware Terraform Validation
// Copy this script directly into Jenkins Pipeline job configuration
// Use for Pull Request validation before merging code

pipeline {
    agent {
        label 'terraform-agent'
    }
    
    parameters {
        string(
            name: 'GIT_REPO_URL',
            defaultValue: 'https://github.com/your-org/virtualization-automation.git',
            description: 'Git repository URL to validate'
        )
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'main',
            description: 'Branch to validate'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "[CHECKOUT] Cloning repository: ${params.GIT_REPO_URL}"
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
        
        stage('Format Check') {
            steps {
                sh """
                    echo "[CHECK] Validating Terraform formatting"
                    cd terraform-project-template
                    terraform fmt -check -recursive || {
                        echo "[ERROR] Formatting issues found. Run 'terraform fmt -recursive' to fix."
                        exit 1
                    }
                    echo "[OK] Formatting check passed"
                """
            }
        }
        
        stage('Terraform Validate') {
            steps {
                sh """
                    echo "[VALIDATE] Initializing and validating Terraform"
                    cd terraform-project-template
                    terraform init -backend=false
                    terraform validate
                    echo "[OK] Validation passed"
                """
            }
        }
        
        stage('Security Scan') {
            steps {
                sh """
                    echo "[SCAN] Running Trivy security scan"
                    trivy config terraform-project-template/ \\
                        --format sarif \\
                        --output trivy-validation-report.sarif \\
                        --severity MEDIUM,HIGH,CRITICAL || true
                    
                    echo "[SCAN] Converting SARIF to JUnit format"
                    trivy convert --format template --template '@contrib/junit.tpl' \\
                        trivy-validation-report.sarif > trivy-validation-report.xml || true
                    
                    echo "[OK] Security scan completed"
                """
            }
        }
    }
    
    post {
        success {
            script {
                echo "[SUCCESS] Validation passed for all checks"
            }
        }
        failure {
            script {
                echo "[FAILURE] Validation failed. Check logs above."
            }
        }
        always {
            // Archive reports
            archiveArtifacts artifacts: '**/*-report.*', allowEmptyArchive: true
            
            // Publish JUnit test results
            junit testResults: '**/*-report.xml', allowEmptyResults: true
            
            cleanWs()
        }
    }
}
