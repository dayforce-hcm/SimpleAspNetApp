(function () {
    'use strict';

    document.addEventListener('DOMContentLoaded', function () {
        const resultsContainer = document.getElementById('results');
        const testButtons = document.querySelectorAll('.test-button');

        testButtons.forEach(function (button) {
            button.addEventListener('click', function () {
                const endpoint = button.getAttribute('data-endpoint');
                const method = button.getAttribute('data-method') || 'GET';
                
                runTest(endpoint, method);
            });
        });

        function runTest(endpoint, method) {
            clearPlaceholder();
            
            const resultItem = createResultItem(endpoint, method, 'Running...');
            resultsContainer.insertBefore(resultItem, resultsContainer.firstChild);
            resultsContainer.scrollTop = 0;

            const xhr = new XMLHttpRequest();
            xhr.open(method, endpoint, true);
            
            xhr.onload = function () {
                if (xhr.status >= 200 && xhr.status < 300) {
                    updateResultItem(resultItem, 'success', xhr.responseText, xhr.status);
                } else {
                    updateResultItem(resultItem, 'error', xhr.responseText, xhr.status);
                }
            };

            xhr.onerror = function () {
                updateResultItem(resultItem, 'error', 'Network error occurred', 0);
            };

            xhr.send();
        }

        function clearPlaceholder() {
            const placeholder = resultsContainer.querySelector('.placeholder');
            if (placeholder) {
                placeholder.remove();
            }
        }

        function createResultItem(endpoint, method, status) {
            const item = document.createElement('div');
            item.className = 'result-item';
            
            const header = document.createElement('div');
            header.className = 'result-header';
            header.textContent = method + ' ' + endpoint;
            
            const statusSpan = document.createElement('span');
            statusSpan.className = 'result-status';
            statusSpan.textContent = status;
            header.appendChild(statusSpan);
            
            const content = document.createElement('div');
            content.className = 'result-content';
            content.textContent = 'Loading...';
            
            item.appendChild(header);
            item.appendChild(content);
            
            return item;
        }

        function updateResultItem(item, status, content, httpStatus) {
            const statusSpan = item.querySelector('.result-status');
            statusSpan.className = 'result-status status-' + status;
            statusSpan.textContent = status.toUpperCase() + ' (' + httpStatus + ')';
            
            const contentDiv = item.querySelector('.result-content');
            
            // Try to format JSON
            try {
                const json = JSON.parse(content);
                contentDiv.textContent = JSON.stringify(json, null, 2);
            } catch (e) {
                contentDiv.textContent = content;
            }
        }
    });
})();
