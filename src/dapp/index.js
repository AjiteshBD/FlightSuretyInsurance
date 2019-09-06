
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);

            contract.flights.forEach(flight => {
                displayList(flight, DOM.elid("flights"));
            });
            contract.airlines.forEach(airline => {
                displayListAirline(airline, DOM.elid("airlines"));
            });  
            contract.passengers.forEach(passenger => {
                displayListPassenger(passenger, DOM.elid("passengers"));
            });  
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })
    
    });

    DOM.elid('buy').addEventListener('click', () => {
        let passenger = DOM.elid('passengers').value;
        let flight = DOM.elid('flights').value;
        let insurance = DOM.elid('insurance').value;
        if (insurance > 0) {
            contract.buyInsurance(passenger, insurance, flight, (error, result) => {
                alert("Passenger was able to buy insurance.");
            });
        } else {
            alert("Passenger should buy insurance.");
        }
    });

    DOM.elid('register-airline').addEventListener('click', () => {
        let airline = DOM.elid('airline-address').value;
        contract.registerAirline(airline,(error, result) => {
            alert("Airline was successfully registered.");
        });
        DOM.elid('airline-address').value = "";
        displayListAirline(airline, DOM.elid("airlines"));  
    });

    DOM.elid('pay-fee').addEventListener('click', () => {
        let airline = DOM.elid('airlines').value;
        let fee = DOM.elid('registration-fee').value;
        contract.payAirlineRegistrationFee(airline, fee, (error, result) => {
            alert("Airline was successfully funded.");
        }); 
    });

    DOM.elid('flights').addEventListener('change', () => {
        console.log("Hello" + contract.flights);
        return contract.flights;
    });

    DOM.elid('airlines').addEventListener('change', () => {
        return contract.airlines;
    });

    DOM.elid('withdraw').addEventListener('click', () => {
        let passenger = DOM.elid('passenger-address').value;
        alert(passenger);
        contract.withdraw(passenger, (error, result) => {
            if(error){
                alert(error);
            }
            alert("successfully executed.")
       });
    });

    DOM.elid('amtInsured').addEventListener('click', () => {
        let passenger = DOM.elid('passenger-address2').value;
        contract.getInsuranceAmt(passenger, (error, result) => {
            console.log("insurance SA was successful");
       });
        alert(contract.getInsuranceAmt(passenger));
    });

    

})();

function displayList(flight, parentEl) {
    console.log(flight);
    console.log(parentEl);
    let el = document.createElement("option");
    el.text = `${flight.flight} - ${new Date((flight.timestamp))}`;
    el.value = JSON.stringify(flight);
    parentEl.add(el);
}

function displayListAirline(airline, parentEl) {
    let el = document.createElement("option");
    el.text = airline;
    el.value = airline;
    parentEl.add(el);
}

function displayListPassenger(passenger, parentEl) {
    let el = document.createElement("option");
    el.text = passenger.account;
    el.value = passenger.account;
    parentEl.add(el);
}

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);


}







