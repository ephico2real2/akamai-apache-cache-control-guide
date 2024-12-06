// main.js - Sample file for Apache Cache-Control Testing

// Log a welcome message
console.log("Welcome to the OCP Apache Lab!");

// Dynamically display the current timestamp to test cache expiration behavior
const timestampElement = document.createElement("div");
timestampElement.style = "font-size: 18px; font-weight: bold; margin-top: 20px;";
timestampElement.textContent = `Current Timestamp: ${new Date().toISOString()}`;
document.body.appendChild(timestampElement);

// Add a test message to ensure the file is loaded and executed
console.log("Cache-Control is being tested with this script.");

// Change the background color to confirm updates to the file
// document.body.style.backgroundColor = "#f3f3f3";

// document.body.style.backgroundColor = "#add8e6"; // Change to light blue

document.body.style.backgroundColor = "red";

// Dummy function to simulate dynamic interaction
function testFunction() {
    console.log("This is a test function to simulate script behavior.");
}

// Call the test function
testFunction();
