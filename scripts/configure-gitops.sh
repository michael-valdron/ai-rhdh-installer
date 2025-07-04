#!/bin/bash

RHDH_INSTANCE_PROVIDED=${RHDH_INSTANCE_PROVIDED:-false}
ARGOCD_INSTANCE_PROVIDED=${ARGOCD_INSTANCE_PROVIDED:-false}
NAMESPACE=${NAMESPACE:-"ai-rhdh"}

RHDH_ARGOCD_SECRET='rhdh-argocd-secret'
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."

EXISTING_NAMESPACE=${EXISTING_NAMESPACE:-''}
ARGO_USERNAME=${ARGO_USERNAME:-''}
ARGO_PASSWORD=${ARGO_PASSWORD:-''}
ARGO_HOSTNAME=${ARGO_HOSTNAME:-''}
ARGO_TOKEN=${ARGO_TOKEN:-''}

# RHDH Instance Created By Installer
echo "Applying ArgoCD ConfigMaps"
if [[ $RHDH_INSTANCE_PROVIDED == "false" ]]; then
    # Add ConfigMap To Configure ArgoCD
    kubectl apply -n $NAMESPACE -f $BASE_DIR/resources/argocd-config.yaml
else
    until [ ! -z "${EXISTING_NAMESPACE}" ]; do
        read -p "Enter the namespace of your RHDH instance: " EXISTING_NAMESPACE
        if [ -z "${EXISTING_NAMESPACE}" ]; then
            echo "No namespace entered, try again."
        fi
    done
    # Create the plugin and config setup configmaps in the namespace
    kubectl apply -n $EXISTING_NAMESPACE -f $BASE_DIR/resources/argocd-config.yaml
fi

# ArgoCD Instance Brought By User
# If a user is using this step it is assumed they did not use our installer so we need ALL the information required with no assumptions
if [[ $ARGOCD_INSTANCE_PROVIDED == "true" ]] && [[ -z "$(kubectl get secret -n $NAMESPACE $RHDH_ARGOCD_SECRET --ignore-not-found)" ]]; then
    # Gather ArgoCD instance information
    echo "You have chosen to provide your own ArgoCD instance"

    until [ ! -z "${ARGO_USERNAME}" ]; do
        read -p "Enter your ArgoCD username: " ARGO_USERNAME
        if [ -z "${ARGO_USERNAME}" ]; then
            echo "No username entered, try again."
        fi
    done

    until [ ! -z "${ARGO_PASSWORD}" ]; do
        read -p "Enter password for $ARGO_USERNAME: " ARGO_PASSWORD
        if [ -z "${ARGO_PASSWORD}" ]; then
            echo "No password entered, try again."
        fi
    done

    until [ ! -z "${ARGO_HOSTNAME}" ]; do
        read -p "Enter your ArgoCD hostname: " ARGO_HOSTNAME
        if [ -z "${ARGO_HOSTNAME}" ]; then
            echo "No hostname entered, try again."
        fi
    done
    
    until [ ! -z "${ARGO_TOKEN}" ]; do
        read -p "Enter your ArgoCD token: " ARGO_TOKEN
        if [ -z "${ARGO_TOKEN}" ]; then
            echo "No token entered, try again."
        fi
    done
    
    echo "Creating ArgoCD secret file"
    if [[ $RHDH_INSTANCE_PROVIDED == "false" ]]; then
        # Create the secret in the namespace so we can connect it to rhdh TODO: need the setup namespace input
        kubectl create secret generic "$RHDH_ARGOCD_SECRET" \
                --from-literal="ARGOCD_API_TOKEN=$ARGO_TOKEN" \
                --from-literal="ARGOCD_HOSTNAME=$ARGO_HOSTNAME" \
                --from-literal="ARGOCD_PASSWORD=$ARGO_PASSWORD" \
                --from-literal="ARGOCD_USER=$ARGO_USERNAME" \
                -n "$NAMESPACE" \
                > /dev/null
    else
        # Create the secret in the namespace so we can connect it to rhdh TODO: need the setup namespace input
        kubectl create secret generic "$RHDH_ARGOCD_SECRET" \
                --from-literal="ARGOCD_API_TOKEN=$ARGO_TOKEN" \
                --from-literal="ARGOCD_HOSTNAME=$ARGO_HOSTNAME" \
                --from-literal="ARGOCD_PASSWORD=$ARGO_PASSWORD" \
                --from-literal="ARGOCD_USER=$ARGO_USERNAME" \
                -n "$EXISTING_NAMESPACE" \
                > /dev/null
    fi
fi