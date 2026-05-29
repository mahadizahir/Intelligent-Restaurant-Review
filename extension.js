const vscode = require('vscode');
const path = require('path');
const fs = require('fs');

function activate(context) {
    console.log('Restaurant Review Extension is now active!');
    
    let disposable = vscode.commands.registerCommand('restaurant-review.start', () => {
        const panel = vscode.window.createWebviewPanel(
            'restaurantReview',
            '🍽️ Restaurant Intelligent Review',
            vscode.ViewColumn.One,
            {
                enableScripts: true,
                retainContextWhenHidden: true
            }
        );
        
        const htmlPath = path.join(context.extensionPath, 'premium.html');
        let htmlContent = fs.readFileSync(htmlPath, 'utf8');
        panel.webview.html = htmlContent;
    });
    
    context.subscriptions.push(disposable);
}

function deactivate() {}

module.exports = { activate, deactivate };
