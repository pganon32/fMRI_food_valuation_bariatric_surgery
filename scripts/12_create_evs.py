# 1.0.1 added verbose statements

import os
import pandas as pd



# Define the bid_extract function (from your notebook)
def bid_extract(directory_file, filename, verbose=False):  
    try:
        """
        Extracts bid information from a given file and processes it into a DataFrame.

        Args:
            directory_file (str): The directory containing the file.
            filename (str): The name of the file to process.
            verbose (bool): If True, prints debugging information.

        Returns:
            pd.DataFrame: A DataFrame containing the processed bid information.
        """
        if verbose:
            print(f"Starting bid_extract for file: {filename} in directory: {directory_file}")

        # Read the file
        colnames = ['Picture', 'Stim_Start_Time', 'Bid_Start_Time', 'Bid_Duration', 'Price']
        bid = pd.read_csv(os.path.join(directory_file, filename), sep='\t', header=None, names=colnames, skiprows=2, index_col=False)
        if verbose:
            print(f"File read successfully. Columns: {colnames}")

        # After reading file
        required_cols = ['Stim_Start_Time', 'Bid_Start_Time', 'Bid_Duration', 'Price']
        missing_cols = [col for col in required_cols if col not in bid.columns]
        if missing_cols:
            print(f"[ERROR] Missing columns in file {filename}: {missing_cols}")
            return pd.DataFrame()  # Return empty DataFrame to skip further processing

        id_participant = filename[1:4]
        id_participant = int(id_participant)

        if id_participant <= 9:
            id_participant = 'RND00' + str(id_participant)
        elif 10 <= id_participant <= 95:
            id_participant = 'RND0' + str(id_participant)
        elif 96 <= id_participant <= 99:
            id_participant = 'RCX0' + str(id_participant)
        elif 100 <= id_participant <= 899:
            id_participant = 'RCX' + str(id_participant)
        elif id_participant >= 900:
            id_participant = 'RGC' + str(id_participant)

        if verbose:
            print(f"Participant ID determined: {id_participant}")

        session = filename[0:1]
        if session == '1':
            session = 1
        elif session == '2' and id_participant.startswith('RGC'):
            session = 'x'
        elif session == '2':
            session = 2
        elif session == '3' and id_participant.startswith('RGC'):
            session = 2
        elif session == '3':
            session = 3
        elif session == '4':
            session = 4
        else:
            session = 'erreur'

        if verbose:
            print(f"Session determined: {session}")

        run = int(filename[5:6])
        if verbose:
            print(f"Run determined: {run}")

        bid.insert(0, 'id_participant', id_participant)
        bid.insert(1, 'session', session)
        bid.insert(2, 'run', run)

        # Convert columns to numeric, coercing errors
        bid['Bid_Start_Time'] = pd.to_numeric(bid['Bid_Start_Time'], errors='coerce')
        bid['Stim_Start_Time'] = pd.to_numeric(bid['Stim_Start_Time'], errors='coerce')
        bid['Bid_Duration'] = pd.to_numeric(bid['Bid_Duration'], errors='coerce')
        bid['Price'] = pd.to_numeric(bid['Price'], errors='coerce')

        # Handle NaN values if necessary
        bid = bid.dropna(subset=['Bid_Start_Time', 'Stim_Start_Time'])

        if verbose:
            print("Data cleaned and NaN values handled.")

        # Perform the operations
        bid['duration'] = bid['Bid_Start_Time'] - bid['Stim_Start_Time']
        bid['onset_bid_end'] = bid['Bid_Start_Time'] + bid['Bid_Duration']

        # Ensure the split operation produces exactly two columns
        split_columns = bid['Picture'].str.split('/', expand=True, n=1)
        if split_columns.shape[1] == 2:
            bid[['stimuli', 'stim_file']] = split_columns
        else:
            bid['stimuli'] = split_columns[0] if not split_columns.empty else ''
            bid['stim_file'] = ''

        bid['trial_type'] = bid['stim_file'].str[:2]
        bid['stim_file'] = bid['stim_file'].str[2:]
        bid['trial_type2'] = bid["stim_file"].str.extract("(Sweet|Salt)")[0]
        bid['trial_type2'] = bid['trial_type2'].fillna('Lo')
        bid['stim_file'] = bid['stim_file'].str.replace('Sweet', '')
        bid['stim_file'] = bid['stim_file'].str.replace('Salt', '')
        bid.rename({'Stim_Start_Time': 'onset', 'Bid_Start_Time': 'onset_bid', 'Bid_Duration': 'response_time', 'Price': 'value'}, axis=1, inplace=True)
        # After renaming
        if 'onset' not in bid.columns:
            print(f"[ERROR] Column 'onset' missing after renaming in file {filename}")
            return pd.DataFrame()

        if verbose:
            print("Columns processed and renamed.")

        event = bid[['onset', 'duration', 'trial_type', 'trial_type2', 'onset_bid', 'onset_bid_end', 'response_time', 'value', 'stim_file']]

        # Add a new column 'trial_type' with the string value 'view' for all rows
        event['trial_type_3'] = 'view'

        # Create a new DataFrame to store the modified rows
        new_event = pd.DataFrame()

        # Collect indices of view events for later use
        view_indices = []

        for index, row in event.iterrows():
            # Append the original row (view)
            new_event = pd.concat([new_event, pd.DataFrame([row])], ignore_index=True)
            if row['trial_type_3'] == 'view':
                view_indices.append(len(new_event) - 1)

            # Create a new row for bid
            new_row = row.copy()
            new_row['onset'] = row['onset_bid']
            new_row['duration'] = row['onset_bid_end'] - row['onset_bid']
            new_row['trial_type_3'] = 'bid'
            new_event = pd.concat([new_event, pd.DataFrame([new_row])], ignore_index=True)

            # Add press_conf and bid_conf in the correct order
            press_conf_row = row.copy()
            press_conf_row['onset'] = row['onset_bid_end']
            press_conf_row['duration'] = 0.0
            press_conf_row['trial_type_3'] = 'press_conf'

            bid_conf_row = row.copy()
            bid_conf_row['onset'] = row['onset_bid_end']
            bid_conf_row['duration'] = 1.030
            bid_conf_row['trial_type_3'] = 'bid_conf'

            # Append press_conf first, then bid_conf
            new_event = pd.concat([new_event, pd.DataFrame([press_conf_row, bid_conf_row])], ignore_index=True)

        # Use the first view event as template once outside the per-row loop
        if not event.empty:
            first_view = event.iloc[0].copy()
            first_view['duration'] = first_view['onset']
            first_view['onset'] = 0
            first_view['trial_type_3'] = 'view_cross'
            new_event = pd.concat([pd.DataFrame([first_view]), new_event], ignore_index=True)

        # Add view_cross events
        # Sort by onset to ensure correct order
        new_event = new_event.sort_values(by='onset').reset_index(drop=True)

        # Find all bid_conf and view events, sorted by onset
        bid_conf_events = new_event[new_event['trial_type_3'] == 'bid_conf'].copy().sort_values(by='onset').reset_index(drop=True)
        view_events = new_event[new_event['trial_type_3'] == 'view'].copy().sort_values(by='onset').reset_index(drop=True)

        # Add view_cross events after each bid_conf, up to the next event
        for i in range(len(bid_conf_events)):
            bid_conf_row = bid_conf_events.iloc[i]
            view_cross_onset = bid_conf_row['onset'] + bid_conf_row['duration']

            # Find the next event onset after this view_cross onset
            next_events = new_event[new_event['onset'] > view_cross_onset].sort_values(by='onset')
            if not next_events.empty:
                next_event = next_events.iloc[0]
                view_cross_duration = next_event['onset'] - view_cross_onset
                # Use the next view's type/value/stim_file if available, else fallback to next event
                next_view = view_events[view_events['onset'] >= next_event['onset']]
                if not next_view.empty:
                    template_row = next_view.iloc[0]
                else:
                    template_row = next_event
                if view_cross_duration > 0:
                    view_cross_row = template_row.copy()
                    view_cross_row['onset'] = view_cross_onset
                    view_cross_row['duration'] = view_cross_duration
                    view_cross_row['trial_type_3'] = 'view_cross'
                    new_event = pd.concat([new_event, pd.DataFrame([view_cross_row])], ignore_index=True)

        # Sort by onset to ensure correct order
        new_event = new_event.sort_values(by='onset').reset_index(drop=True)

        # Reorder rows based on conditions
        for i in range(1, len(new_event) - 1):  # Start from index 1 and stop at len(new_event) - 1 to avoid out-of-bounds error
            # Check if press_conf is followed by view_cross
            if 'press_conf' in new_event.loc[i, 'trial_type_3'] and 'view_cross' in new_event.loc[i + 1, 'trial_type_3']:
                # Swap press_conf with the row above (bid_conf)
                press_conf_row = new_event.iloc[i].copy()
                bid_conf_row = new_event.iloc[i - 1].copy()

                # Permutate rows
                new_event.iloc[i] = bid_conf_row
                new_event.iloc[i - 1] = press_conf_row

        # Drop the 'response_time' column
        new_event = new_event.drop(columns=['response_time'])

        new_event = new_event.drop(columns=['onset_bid', 'onset_bid_end'])

        new_event['trial_type'] = new_event['trial_type_3'] + '_' + new_event['trial_type'] + '_' + new_event['trial_type2']

        new_event = new_event.drop(columns=['trial_type2', 'trial_type_3'])

        new_event['value'] = new_event['value'].fillna('n/a')

        event = new_event

        print(event)

        # Save the event file
        output_dir = os.path.expandvars(f'$HOME/projects/def-amichaud/share/GutBrain/data2/sub-{id_participant}/ses-{session}/func')
        os.makedirs(output_dir, exist_ok=True)  # Ensure the directory exists
        output_file = os.path.join(output_dir, f'sub-{id_participant}_ses-{session}_task-BDM_run-{run}_events.tsv')
        event.to_csv(output_file, sep='\t', index=False)

        if verbose:
            print(f"Event file saved: {output_file}")

        return bid

    except Exception as e:
        print(f"[EXCEPTION] Error processing file {filename}: {e}")
        return pd.DataFrame()

directory = os.path.expandvars('$HOME/projects/def-amichaud/share/GutBrain/data/sourcedata')
print(directory)

# Main script
bdd_bid = pd.DataFrame()  # Initialize an empty DataFrame to concatenate results

for root, dirs, files in os.walk(directory):  # Recursively walk through directories
    for filename in files:
        if filename.endswith(".txt"):  # Check for .txt files
            directory_file = os.path.join(root, filename)  # Full path to the file
            print(f"Processing file: {filename} at location: {directory_file}")
            bid = bid_extract(os.path.dirname(directory_file), filename, verbose=False)  # Call bid_extract with verbose=True
            bdd_bid = pd.concat([bdd_bid, bid], sort=False)  # Concatenate results
